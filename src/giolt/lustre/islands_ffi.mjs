export function is_element_registered(name) {
  return !!globalThis.customElements.get(name);
}
