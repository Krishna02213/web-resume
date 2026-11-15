const email = 'krishnasen0006@gmail.com';
document.getElementById('year').textContent = new Date().getFullYear();
const copyButton = document.getElementById('copy-email');
let resetCopy;
copyButton.addEventListener('click', async () => {
  const status = document.getElementById('copy-status');
  try {
    if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
    await navigator.clipboard.writeText(email);
    copyButton.textContent = 'Copied ✓';
    status.textContent = 'Email address copied to clipboard.';
  } catch {
    copyButton.textContent = 'Select email to copy';
    const range = document.createRange();
    range.selectNodeContents(document.querySelector('.email-link'));
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    status.textContent = 'Email selected. Use your device’s copy command.';
  }
  clearTimeout(resetCopy);
  resetCopy = setTimeout(() => { copyButton.innerHTML = 'Copy email <span>⧉</span>'; }, 3000);
});
if ('IntersectionObserver' in window) {
  const navLinks = [...document.querySelectorAll('.site-header nav a')];
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        navLinks.forEach(link => {
          const active = link.hash === '#' + entry.target.id;
          link.classList.toggle('active', active);
          if (active) link.setAttribute('aria-current', 'location');
          else link.removeAttribute('aria-current');
        });
      }
    }
  }, { rootMargin: '-15% 0px -45% 0px', threshold: 0 });
  document.querySelectorAll('#work, #about, #experience').forEach(section => observer.observe(section));
}
