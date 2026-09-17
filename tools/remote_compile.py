"""Strict preview compiler; never evaluates ALU results. Bytecode ABI v1+v2 (single-cycle dual-LUT)."""
import re
import ast
OPS={'ADD':2,'SUB':3,'AND':4,'OR':5,'XOR':6,'MASKADD':7,'XORAND':8,'ANDADD':9,'ORADD':10,'XORADD':11,'ANDN':12,'ORN':13}
class CompileError(ValueError): pass

LEADING_SHELL=re.compile(r'^(?:(?:on|for|from)\s+tomato,\s*|(?:could you please|would you please|can you please|can tomato calc(?:ulate)?|can tomato compute|could tomato calc(?:ulate)?|how much is|how much would|what does|what is|what would|tell me(?:\s+the)?|give me(?:\s+the)?|show me(?:\s+the)?|work out|figure out|(?:the\s+)?(?:result|value|answer)\s+(?:of|to|is)|can you|could you|would you|please (?:calculate|compute|calc|evaluate)|calculate|compute|evaluate|do you know|i (?:need|want)(?:\s+to know)?|find(?:\s+me)?|please|hey|hi|hello)(?:\s+tomato)?,?\s+)',re.I)
TRAILING_FILLER=re.compile(r'\s+(?:(?:on|for|from)\s+tomato|for me|thank you|thanks|please|equals?)[?.!]*\s*$',re.I)
OF_NAMES='plus|minus|and|or|xor|nand|nor|xnor|not|sum|difference|add|subtract|product|times'
OF_ALIAS={'plus':'plus','minus':'minus','and':'and','or':'or','xor':'xor','nand':'nand','nor':'nor','xnor':'xnor','not':'not','sum':'plus','difference':'minus','add':'plus','subtract':'minus','product':'*','times':'*'}
OF_HEAD=re.compile(r'\b(?:the\s+)?(?:bitwise\s+)?('+OF_NAMES+r')\s+(?:of|between)\s+',re.I)
OF_TERM=re.compile(r'(?:plus|minus|or|xor|nand|nor|xnor|sum|difference)\b',re.I)
OP_VOCAB=('plus','minus','and','or','xor','nand','nor','xnor','not','sum','add')
FNOPS={'plus':'+','minus':'-','and':'&','or':'|','xor':'^','nand':'&','nor':'|','xnor':'^'}
FNNEG={'nand','nor','xnor'}
FNHEAD=re.compile(r'\b(plus|minus|and|or|xor|nand|nor|xnor|not|andn|orn|maskadd|xorand|andadd|oradd|xoradd)\s*\(',re.I)
FNOP=re.compile(r'(plus|minus|and|or|xor|nand|nor|xnor|not|andn|orn|maskadd|xorand|andadd|oradd|xoradd|[+\-&|^~(,])\s*$',re.I)
FNOPERAND=re.compile(r'[0-9A-Za-z_)]\s*$')

def strip_shells(expression):
    expression=re.sub(r"\bwhat['’]s\b",'what is',expression,flags=re.I)
    expression=re.sub(r'\bwhats\b','what is',expression,flags=re.I)
    for _ in range(6):
        shell=LEADING_SHELL.sub('',expression,count=1)
        if shell==expression:break
        expression=shell
    expression=expression.rstrip('?.!').strip()
    expression=re.sub(r'\bbitwise\s+','',expression,flags=re.I)
    for _ in range(3):
        short=TRAILING_FILLER.sub('',expression).strip()
        if short==expression:break
        expression=short
    expression=re.sub(r'\b(?:the|a|an)\b',' ',expression,flags=re.I)
    return re.sub(r'\s+',' ',expression).strip()

def _sep_len(s,i):
    if i>=len(s):return 0
    if s[i] in ',&':return 1
    m=re.match(r'with\b',s[i:],re.I)
    if m:return m.end()
    m=re.match(r'and\b',s[i:],re.I)
    if m:return m.end()
    return 0

def _is_term(s,i):
    if i>=len(s):return True
    if s[i] in '+|^':return True
    return bool(OF_TERM.match(s[i:]))

def parse_of_args(s):
    n=len(s);i=0;args=[]
    while True:
        while i<n and s[i].isspace():i+=1
        if i>=n or (args and _is_term(s,i)):break
        start=i;depth=0
        while i<n:
            c=s[i]
            if c=='(':depth+=1;i+=1;continue
            if c==')':
                if depth==0:break
                depth-=1;i+=1;continue
            if depth==0 and i>start and (_sep_len(s,i) or _is_term(s,i)):break
            i+=1
        arg=s[start:i].strip()
        if not arg:break
        args.append(arg)
        while i<n and s[i].isspace():i+=1
        sl=_sep_len(s,i)
        if sl:i+=sl;continue
        break
    return args,i

def expand_of(s,depth=0):
    if depth>8:return s
    matches=list(OF_HEAD.finditer(s))
    if not matches:return s
    m=matches[-1]
    name=OF_ALIAS[m.group(1).lower()]
    rest=s[m.end():]
    args,consumed=parse_of_args(rest)
    args=[a.strip() for a in args if a.strip()]
    ok=(name=='not' and len(args)==1) or (name!='not' and 2<=len(args)<=8)
    if not ok:return s[:m.end()]+expand_of(rest,depth+1)
    args=[expand_of(a,depth+1) for a in args]
    if name=='*':made='('+' * '.join(args)+')'
    elif name=='not':made=f'not({args[0]})'
    else:made=f'{name}({", ".join(args)})'
    return expand_of(s[:m.start()]+made+rest[consumed:],depth+1)

def split_args(inner):
    parts,nest,cur=[],0,''
    for ch in inner:
        if ch=='(':nest+=1;cur+=ch
        elif ch==')':nest-=1;cur+=ch
        elif ch==',' and nest==0:parts.append(cur);cur=''
        else:cur+=ch
    parts.append(cur)
    return [p.strip() for p in parts]

def expand_fn(s,depth=0,after_operand=False):
    if depth>32:raise CompileError('ERR EXPRESSION_TOO_DEEP')
    m=FNHEAD.search(s)
    if not m:return s
    before=s[:m.start()]
    if FNOP.search(before):call=True
    elif FNOPERAND.search(before):call=False
    else:call=not after_operand
    if not call:
        nm=m.start()+len(m.group(1))
        return s[:nm]+expand_fn(s[nm:],depth,True)
    name=m.group(1).lower()
    j=m.end();nest=1
    while j<len(s) and nest:
        if s[j]=='(':nest+=1
        elif s[j]==')':nest-=1
        j+=1
    if nest:raise CompileError('ERR FN_ARITY: use name(a, b[, ...]) with two to eight arguments')
    args=split_args(s[m.end():j-1])
    if name=='not':
        if len(args)!=1 or not all(args):raise CompileError("ERR FN_ARITY: not(a) needs exactly one argument")
        made='~('+expand_fn(args[0],depth+1)+')'
        return before+made+expand_fn(s[j:],depth,True)
    if name in ('maskadd','xorand','andadd','oradd','xoradd','andn','orn'):
        need=3 if name in ('maskadd','xorand','andadd','oradd','xoradd') else 2
        if len(args)!=need or not all(args):raise CompileError(f"ERR FN_ARITY: {name} needs exactly {need} arguments")
        ea=[expand_fn(a,depth+1) for a in args]
        made=f"{name}({', '.join(ea)})"
        return before+made+expand_fn(s[j:],depth,True)
    if len(args)<2 or len(args)>8 or not all(args):raise CompileError('ERR FN_ARITY: use name(a, b[, ...]) with two to eight arguments')
    fold=expand_fn(args[0],depth+1)
    for a in args[1:]:fold='('+fold+' '+FNOPS[name]+' '+expand_fn(a,depth+1)+')'
    made='~('+fold+')' if name in FNNEG else fold
    return before+made+expand_fn(s[j:],depth,True)

def edit_distance(a,b):
    if abs(len(a)-len(b))>1:return 2
    if a==b:return 0
    if len(a)>len(b):a,b=b,a
    if len(a)==len(b):return sum(x!=y for x,y in zip(a,b))
    i=j=d=0
    while i<len(a) and j<len(b):
        if a[i]==b[j]:i+=1;j+=1
        else:
            d+=1
            if d>1:return d
            j+=1
    return d+(len(b)-j)

def lower_expression(expression,explicit=False):
    expression=expand_of(expression)
    expression=expand_fn(expression)
    for word,op in [('plus','+'),('minus','-'),('and','&'),('or','|'),('xor','^')]:
        expression=re.sub(r'\b'+word+r'\b',op,expression,flags=re.I)
    if explicit or re.match(r'^(?:[0-9(~+\-^&|]|R[0-7]\b|(?:maskadd|xorand|andadd|oradd|xoradd|andn|orn)\s*\()',expression,re.I) or (re.search(r'\d',expression) and re.search(r'[+\-&|^~]|\bof\b',expression)):
        canonical,understood=expression_program(expression)
        return expression,canonical,understood
    return None

def unknown_hint(prepared,word):
    w=word.lower()
    if w=='of':
        m=re.search(r'\b(xnor|xor|nand|nor|plus|minus|difference|and|or|not|sum)\b',prepared,re.I)
        op=(m.group(1).lower() if m else 'xor')
        op=OF_ALIAS.get(op,op)
        return f' Supported forms: {op} of a and b, or {op}(a, b).'
    hits=[o for o in OP_VOCAB if edit_distance(w,o)==1]
    if len(hits)==1:return f' Closest supported operator: {hits[0]}.'
    words=prepared.split()
    for i in range(1,len(words)):
        prefix=' '.join(words[:i])
        if re.search(r'\d',prefix):break
        rest=' '.join(words[i:])
        try:
            if lower_expression(rest) is not None:return f' Recognized calculation: {rest}.'
        except CompileError:
            continue
    return ''

def interpret(source):
    original=source
    if not isinstance(source,str) or len(source)>2048:raise CompileError('ERR SOURCE_TOO_LONG')
    source=source.strip()
    if re.match(r'^/run\b',source,re.I):
        canonical='/run'+source[4:]
        return {'kind':'program','original':original,'canonical':canonical,'job':compile_job(canonical).hex()}
    explicit=source.lower().startswith('/calc ')
    prepared=strip_shells(source[6:] if explicit else source)
    try:
        lowered=lower_expression(prepared,explicit)
    except CompileError as e:
        hint=''
        m=re.search(r"UNKNOWN_WORD: '([^']+)'",str(e))
        if m:hint=unknown_hint(prepared,m.group(1))
        raise CompileError(str(e)+hint) from None
    if lowered is not None:
        expression,canonical,understood=lowered
        return {'kind':'compute','original':original,'normalized':expression,'canonical':canonical,'understood':understood,'job':compile_job(canonical).hex()}
    key=source.lower().rstrip('!.?').strip()
    greet=re.fullmatch(r'(hi|hey|hello)\s*,?\s*(tomato)?\s*[!.?]*',source.strip(),flags=re.I)
    chat='Hello' if greet else '/help' if key in {'/help','help','what can you do'} else source
    return {'kind':'chat','original':original,'canonical':chat,'job':None}

BINOPS={ast.Add:'ADD',ast.Sub:'SUB',ast.BitAnd:'AND',ast.BitOr:'OR',ast.BitXor:'XOR'}
UNSUP={ast.Mult:'*',ast.Div:'/',ast.Mod:'%',ast.FloorDiv:'//',ast.Pow:'**',ast.LShift:'<<',ast.RShift:'>>'}
SYM={'ADD':'+','SUB':'-','AND':'&','OR':'|','XOR':'^'}
TRI_OPS={'maskadd':'MASKADD','xorand':'XORAND','andadd':'ANDADD','oradd':'ORADD','xoradd':'XORADD'}
BIN2_OPS={'andn':'ANDN','orn':'ORN'}

def expression_program(expression):
    if len(expression)>1024:raise CompileError('ERR SOURCE_TOO_LONG')
    reserved=set()
    for w in re.findall(r'(?<![0-9A-Za-z_])[A-Za-z_][A-Za-z0-9_]*',expression):
        lw=w.lower()
        if re.fullmatch(r'R[0-7]',w,re.I):reserved.add(int(w[1:]))
        elif re.fullmatch(r'R[0-9]+',w,re.I):raise CompileError('ERR REGISTER_RANGE: use R0-R7')
        elif lw in TRI_OPS or lw in BIN2_OPS:continue
        else:raise CompileError(f"ERR UNKNOWN_WORD: '{w}' is not supported")
    try:tree=ast.parse(expression,mode='eval')
    except (SyntaxError,RecursionError):raise CompileError('ERR EXPRESSION_SYNTAX')
    def parse(node,depth=0):
        if depth>32:raise CompileError('ERR EXPRESSION_TOO_DEEP')
        if isinstance(node,ast.Constant) and type(node.value) is int:
            return ('const',node.value,ast.get_source_segment(expression,node) or str(node.value))
        if isinstance(node,ast.Name) and re.fullmatch(r'R[0-7]',node.id,re.I):
            return ('reg',int(node.id[1:]))
        if isinstance(node,ast.UnaryOp) and isinstance(node.op,ast.USub) and isinstance(node.operand,ast.Constant) and type(node.operand.value) is int:
            v=-node.operand.value
            return ('const',v,'-'+(ast.get_source_segment(expression,node.operand) or str(node.operand.value)))
        if isinstance(node,ast.UnaryOp) and isinstance(node.op,ast.Invert):
            return ('not',parse(node.operand,depth+1))
        if isinstance(node,ast.BinOp) and type(node.op) in BINOPS:
            return ('bin',BINOPS[type(node.op)],parse(node.left,depth+1),parse(node.right,depth+1))
        if isinstance(node,ast.BinOp) and type(node.op) in UNSUP:
            raise CompileError(f"ERR UNSUPPORTED_OP: '{UNSUP[type(node.op)]}' is not installed")
        if isinstance(node,ast.Call) and isinstance(node.func,ast.Name):
            fn=node.func.id.lower()
            if fn in TRI_OPS:
                if len(node.args)!=3 or node.keywords:raise CompileError(f"ERR FN_ARITY: {fn} needs exactly 3 arguments")
                return ('tri',TRI_OPS[fn],fn,[parse(a,depth+1) for a in node.args])
            if fn in BIN2_OPS:
                if len(node.args)!=2 or node.keywords:raise CompileError(f"ERR FN_ARITY: {fn} needs exactly 2 arguments")
                return ('bin2',BIN2_OPS[fn],fn,[parse(a,depth+1) for a in node.args])
            raise CompileError(f"ERR UNKNOWN_WORD: '{node.func.id}' is not supported")
        raise CompileError('ERR UNSUPPORTED_EXPRESSION: use + - & | ^ ~ and parentheses')
    try:root=parse(tree.body)
    except RecursionError:raise CompileError('ERR EXPRESSION_SYNTAX')
    def show(n):
        k=n[0]
        if k=='const':return n[2]
        if k=='reg':return f'R{n[1]}'
        if k=='not':
            s=show(n[1]);return '~'+(s if n[1][0] in ('const','reg') else f'({s})')
        if k=='tri':return f"{n[2]}({', '.join(show(a) for a in n[3])})"
        if k=='bin2':return f"{n[2]}({', '.join(show(a) for a in n[3])})"
        return f'({show(n[2])} {SYM[n[1]]} {show(n[3])})'
    understood=show(root);understood=understood[1:-1] if understood.startswith('(') and understood.endswith(')') else understood
    free=[r for r in range(7,-1,-1) if r not in reserved];lines=[]
    def alloc():
        if not free:raise CompileError('ERR REGISTER_PRESSURE')
        return free.pop()
    def copy(a):
        t=alloc();lines.append(f'OR R{t},R{a},R{a}');return t
    def gen(n,depth=0):
        if depth>32:raise CompileError('ERR EXPRESSION_TOO_DEEP')
        k=n[0]
        if k=='const':
            r=alloc();literal(str(n[1]));lines.append(f'R{r}={n[1]}');return r
        if k=='reg':return n[1]
        if k=='not':
            a=gen(n[1],depth+1)
            if a in reserved:a=copy(a)
            c=alloc();lines.append(f'R{c}=4294967295');lines.append(f'XOR R{a},R{a},R{c}');free.append(c);return a
        if k=='tri':
            _,op,_,args=n
            regs=[gen(a,depth+1) for a in args]
            ra,rb,rc=regs
            if ra in reserved:ra=copy(ra)
            lines.append(f'{op} R{ra},R{ra},R{rb},R{rc}')
            for t in (rb,rc):
                if t not in reserved and t!=ra:free.append(t)
            return ra
        if k=='bin2':
            _,op,_,args=n
            ra=gen(args[0],depth+1);rb=gen(args[1],depth+1)
            if ra in reserved:ra=copy(ra)
            lines.append(f'{op} R{ra},R{ra},R{rb}')
            if rb not in reserved and rb!=ra:free.append(rb)
            return ra
        _,op,l,r=n
        a=gen(l,depth+1);b=gen(r,depth+1)
        if a in reserved:a=copy(a)
        lines.append(f'{op} R{a},R{a},R{b}')
        if b not in reserved:free.append(b)
        return a
    try:r=gen(root)
    except RecursionError:raise CompileError('ERR EXPRESSION_SYNTAX')
    return '/run\n'+'\n'.join(lines+[f'RETURN R{r}']),understood
def literal(s):
    if not re.fullmatch(r'-?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|[0-9]+)',s):raise CompileError('ERR LITERAL')
    try: v=int(s, 0) if s.lower().startswith(('0x','0b','-0x','-0b')) else int(s,10)
    except ValueError: raise CompileError('ERR LITERAL')
    if not -(1<<31)<=v<1<<32: raise CompileError('ERR LITERAL_RANGE')
    return v & 0xffffffff
def reg(s):
    if not re.fullmatch(r'R[0-7]',s.upper()): raise CompileError('ERR REGISTER_RANGE')
    return int(s[1])
def compile_job(source):
    if len(source)>2048:raise CompileError('ERR SOURCE_TOO_LONG')
    if source.startswith('/calc '):
        m=re.fullmatch(r'/calc\s+(-?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|[0-9]+))\s*([+\-&|^])\s*(-?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|[0-9]+))\s*',source)
        if not m:raise CompileError('ERR CALC_SYNTAX: /calc 23 + 19')
        a,op,b=m.groups();source=f'/run R0={a};R1={b};'+{'+':'ADD','-':'SUB','&':'AND','|':'OR','^':'XOR'}[op]+' R2,R0,R1;RETURN R2'
    if not re.match(r'^/run(?:\s|$)',source):raise CompileError('ERR COMMAND: use /help, /calc or /run')
    lines=[s.strip() for s in re.split(r'[;\n]',source[4:].strip()) if s.strip()]
    if len(lines)>32:raise CompileError('ERR PROGRAM_TOO_LONG')
    out=bytearray();returned=False
    for raw_line in lines:
        line=raw_line
        # Phase-1 /run aliases (no new bytecode): LD/LI->SET, LD->[LOAD], ST->[STORE], MOV->OR, CLR->SET 0.
        am= re.fullmatch(r'(LD|LI)\s+(R\d+)\s*,?\s*(\[(\d+)\]|(\S+))', raw_line, re.I)
        if am:
            rd,br,off,imm=am.group(2),am.group(4),am.group(4),am.group(5)
            if br is not None:line=f'LOAD {rd},[{off}]'
            else:line=f'{rd}={imm}'
        else:
            am=re.fullmatch(r'ST\s*\[(\d+)\]\s*,?\s*(R\d+)', raw_line, re.I)
            if am:line=f'STORE [{am.group(1)}],{am.group(2)}'
            else:
                am=re.fullmatch(r'MOV\s+(R\d+)\s*,?\s*(R\d+)', raw_line, re.I)
                if am:line=f'OR {am.group(1)},{am.group(2)},{am.group(2)}'
                else:
                    am=re.fullmatch(r'CLR\s+(R\d+)', raw_line, re.I)
                    if am:line=f'{am.group(1)}=0'
        if returned:raise CompileError('ERR RETURN_MUST_BE_LAST')
        m=re.fullmatch(r'(R\d+)\s*=\s*(\S+)',line,re.I)
        if m:
            out.extend([1,reg(m[1])]);out.extend(literal(m[2]).to_bytes(4,'big'));continue
        parts=line.replace(',',' ').split();op=parts[0].upper()
        if op in ('LUT','LUTCFG','LUTEXEC'):raise CompileError('ERR UNSUPPORTED_RAW_LUT: ISA extension not installed')
        if op in OPS:
            n=4 if op in ('MASKADD','XORAND','ANDADD','ORADD','XORADD') else 3
            if len(parts)!=n+1:raise CompileError('ERR OPERANDS')
            rr=[reg(x) for x in parts[1:]]
            if n==3:rr.append(0)
            out.extend([OPS[op],*rr])
        elif op in ('LOAD','STORE'):
            m=re.fullmatch(r'(?:LOAD\s+(R\d+)\s*,\s*\[(\d+)\]|STORE\s*\[(\d+)\]\s*,\s*(R\d+))',line,re.I)
            if not m:raise CompileError('ERR MEMORY_SYNTAX')
            r=reg(m[1] or m[4]);offset=int(m[2] or m[3])
            if not 0<=offset<=255:raise CompileError('ERR MEMORY_RANGE')
            out.extend([32 if op=='LOAD' else 33,r,offset])
        elif op=='RETURN':
            if len(parts)!=2:raise CompileError('ERR OPERANDS')
            out.extend([48,reg(parts[1])]);returned=True
        else:raise CompileError('ERR INVALID_OPCODE: '+op)
    if not returned:raise CompileError('ERR MISSING_RETURN')
    return bytes([1])+out
