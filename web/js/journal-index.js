const entries = [...document.querySelectorAll('.journal-row')];
entries.forEach((entry, index) => {
  const number = entry.querySelector('.journal-number');
  if (number) number.textContent = String(entries.length - index).padStart(2, '0');
});

const search = document.querySelector('[data-journal-search]');
const period = document.querySelector('[data-journal-period]');
const count = document.querySelector('[data-journal-count]');
const empty = document.querySelector('[data-journal-empty]');
const tools = document.querySelector('[data-journal-tools]');

const updateEntries = () => {
  const query = search?.value.trim().toLocaleLowerCase() || '';
  const selectedPeriod = period?.value || '';
  let visible = 0;

  entries.forEach((entry) => {
    const date = entry.querySelector('.journal-date')?.textContent || '';
    const matchesQuery = !query || entry.textContent.toLocaleLowerCase().includes(query);
    const matchesPeriod = !selectedPeriod || date.includes(selectedPeriod);
    entry.hidden = !(matchesQuery && matchesPeriod);
    if (!entry.hidden) visible += 1;
  });

  if (count) count.textContent = String(visible);
  if (empty) empty.hidden = visible !== 0;
};

tools?.addEventListener('submit', (event) => event.preventDefault());
search?.addEventListener('input', updateEntries);
period?.addEventListener('change', updateEntries);
updateEntries();
