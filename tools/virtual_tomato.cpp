// Interactive RTL runner. Stdout is a framed binary protocol for the local UI.
#include "Vvirtual_tomato.h"
#include "verilated.h"
#include <array>
#include <deque>
#include <vector>
#include <string>
#include <iostream>
#include <sstream>
#include <cstdint>
#include <iomanip>
using Bytes=std::vector<uint8_t>;
uint16_t crc(const Bytes &b) {
 uint16_t c=0xffff;
 for(auto x:b){c^=uint16_t(x)<<8;for(int i=0;i<8;i++)c=(c<<1)^((c&0x8000)?0x1021:0);}
 return c;
}
Bytes frame(int type,int route,const Bytes &p) {
 Bytes b={80,71,1,uint8_t(type),uint8_t(route>>8),uint8_t(route),uint8_t(p.size()>>8),uint8_t(p.size())};
 b.insert(b.end(),p.begin(),p.end());auto c=crc(b);b.push_back(c>>8);b.push_back(c);return b;
}
// A simulated radio/phone, at the ACI mailbox boundary (not electrical SPI).
struct Radio {
 bool done=false, attached=false, demo=false;
 int length=0,setups=0;
 std::array<uint8_t,32> command{};
 Bytes event, stream;
 std::deque<Bytes> events;
 uint32_t token=100;
 void reset(){done=false;attached=false;length=0;setups=0;event.clear();stream.clear();events.clear();events.push_back({0x81,2,0,3});}
 void receive(const Bytes &b) {
  for(size_t i=0;i<b.size();i+=20) {
   Bytes e={0x8c,2};e.insert(e.end(),b.begin()+i,b.begin()+std::min(b.size(),i+20));events.push_back(e);
  }
 }
 void connect() {
  if(attached || !demo || setups<21)return;
  attached=true;events.push_back({0x85});events.push_back({0x88,8});receive(frame(1,0,{}));
 }
 void message(int route,const std::string &text) {
  if(!attached)return;
  ++token;Bytes p={uint8_t(token>>24),uint8_t(token>>16),uint8_t(token>>8),uint8_t(token)};
  p.insert(p.end(),text.begin(),text.end());receive(frame(7,route,p));
 }
 void outgoing() {
  while(stream.size()>=10) {
   if(stream[0]!=80 || stream[1]!=71){stream.erase(stream.begin());continue;}
   size_t len=(stream[6]<<8)|stream[7], total=len+10;
   if(len>512){stream.erase(stream.begin());continue;}
   if(stream.size()<total)return;
   Bytes checked(stream.begin(),stream.begin()+len+8);
   if(crc(checked)!=((stream[len+8]<<8)|stream[len+9])){stream.erase(stream.begin());continue;}
   int type=stream[3],route=(stream[4]<<8)|stream[5];
   Bytes p(stream.begin()+8,stream.begin()+8+len);
   stream.erase(stream.begin(),stream.begin()+total);
   if(type==8 || type==33) {
    std::cerr << "TX " << route << " " << type << " ";
    for(auto b:p) std::cerr << std::hex << std::setw(2) << std::setfill('0') << int(b);
    std::cerr << std::dec << std::endl;
   }
   if(type==2 && std::string(p.begin(),p.end())=="ENVELOP/1\nDEVICE=TOMATO\nID=TOMATO-001") {
    receive(frame(3,0,{}));
    for(int i=0;i<3;i++){
     std::string name=i==0?"Ama Mensah":i==1?"Kofi":"Ada";
     Bytes contact={uint8_t(i),0};contact.insert(contact.end(),name.begin(),name.end());
     receive(frame(4,i+1,contact));
    }
    message(1,"Hello");
   }
   if(type==8 && p.size()>=5) {
    receive(frame(9,route,Bytes(p.begin(),p.begin()+4)));
   }
  }
 }
 uint32_t read(int a) {
  if(a&64)return (size_t(a&31)<event.size())?event[a&31]:0;
  if(a==1)return length;if(a==2)return event.size();
  return 8|(events.empty()?4:0)|(done?1:0);
 }
 void write(int a,int d) {
  if(a>=32 && a<64){command[a-32]=d;return;}
  if(a==1){length=d&31;return;}
  if(a!=0)return;
  if(d&4){reset();return;}
  if(d&2)done=false;
  if(!(d&1))return;
  // Capture preexisting event; command responses arrive in later transactions.
  event.clear();if(!events.empty()){event=events.front();events.pop_front();}
  if(length) {
   int op=command[0];
   if(op==6){++setups;events.push_back({0x84,6,uint8_t(setups==21?2:1)});if(setups==21)events.push_back({0x81,3,0,3});}
   else if(op==0x0d)events.push_back({0x84,0x0d,0});
   else if(op==0x0f){events.push_back({0x84,0x0f,0});connect();}
   else if(op==0x15){
    for(int i=2;i<length;i++)stream.push_back(command[i]);
    events.push_back({0x8a,1});outgoing();
   }
  }
  done=true;
 }
};
int main(int argc,char**argv) {
 Verilated::commandArgs(argc,argv);
 Vvirtual_tomato cpu;
 Radio radio;radio.reset();
 cpu.clk=0;cpu.pix_clk=0;cpu.reset=1;cpu.key_valid=0;cpu.tile_addr=0;
 auto cycle=[&](){
  cpu.clk=0;cpu.ble_rdata=radio.read(cpu.ble_addr);cpu.eval();
  cpu.ble_rdata=radio.read(cpu.ble_addr);cpu.eval();
  bool consume=cpu.key_read,wr=cpu.ble_wr;int a=cpu.ble_addr,d=cpu.ble_wdata;
  cpu.clk=1;cpu.eval();
  if(wr)radio.write(a,d);if(consume)cpu.key_valid=0;
 };
 for(int i=0;i<4;i++)cycle();cpu.reset=0;
 auto output=[&](){
  // CPU frozen while reading a coherent tile snapshot through its actual RAM port.
  std::cout.write("TOM1",4);
  uint32_t status=cpu.halted|(radio.attached?2:0)|(cpu.menu_selection<<8);
  auto word=[&](uint32_t w){for(int i=0;i<4;i++)std::cout.put((w>>(8*i))&255);};
  word(status);
  for(int i=0;i<4800;i++){
   cpu.tile_addr=i;cpu.pix_clk=0;cpu.eval();cpu.pix_clk=1;cpu.eval();word(cpu.tile_data);
  }
  cpu.pix_clk=0;cpu.eval();std::cout.flush();
 };
 std::string line;
 while(std::getline(std::cin,line)) {
  std::istringstream in(line);std::string op;in>>op;
  if(op=="quit")break;
  if(op=="key"){int k;in>>k;cpu.key=k;cpu.key_valid=1;}
  if(op=="demo"){radio.demo=true;radio.connect();}
  if(op=="contact"){
   int route;in>>route;std::string name;std::getline(in,name);if(!name.empty())name.erase(0,1);
   if(radio.attached){Bytes p={0,0};p.insert(p.end(),name.begin(),name.end());radio.receive(frame(4,route,p));}
  }
  if(op=="message"){int route;in>>route;std::string text;std::getline(in,text);if(!text.empty())text.erase(0,1);radio.message(route,text);}
  if(op=="job") {
   int route;std::string hex;in>>route>>hex;
   if(radio.attached && hex.size()<=394 && hex.size()%2==0) {
    ++radio.token;Bytes p={uint8_t(radio.token>>24),uint8_t(radio.token>>16),uint8_t(radio.token>>8),uint8_t(radio.token)};
    for(size_t i=0;i<hex.size();i+=2)p.push_back(std::stoul(hex.substr(i,2),nullptr,16));
    radio.receive(frame(32,route,p));
   }
  }
  if(op=="reset"){cpu.reset=1;radio.reset();for(int i=0;i<4;i++)cycle();cpu.reset=0;}
  if(op=="disconnect"){radio.demo=false;radio.attached=false;radio.events.clear();radio.stream.clear();radio.events.push_back({0x86,0,0});}
  int count=op=="boot"?400000:105000;
  for(int i=0;i<count;i++)cycle();
  output();
 }
 cpu.final();
}
