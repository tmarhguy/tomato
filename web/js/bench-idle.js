/** Idle is measured from user input, never from animation-generated changes. */
export function createBenchIdle({ delayMs = 0, onIdle, setTimer = setTimeout, clearTimer = clearTimeout }) {
  let timer, dragging = false, held = false, active = true, disposed = false;
  const cancel = () => { if (timer !== undefined) clearTimer(timer); timer = undefined; };
  const activity = () => {
    cancel();
    if (!delayMs || dragging || held || !active || disposed) return;
    timer = setTimer(() => { timer = undefined; onIdle(); }, delayMs);
  };
  return {
    activity,
    begin() { dragging = true; cancel(); },
    end() { dragging = false; activity(); },
    hold(value) { held = value; activity(); },
    setActive(value) { active = value; activity(); },
    dispose() { disposed = true; cancel(); },
  };
}
