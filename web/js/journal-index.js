const entries = [...document.querySelectorAll('.journal-row')];
entries.forEach((entry, index) => {
  const number = entry.querySelector('.journal-number');
  if (number) number.textContent = String(entries.length - index).padStart(2, '0');
});
