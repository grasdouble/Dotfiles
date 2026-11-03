export function resolveReinstallSelection(selectedIds, activeProgram, inventory) {
  const candidates = selectedIds.size
    ? inventory.filter(({ id }) => selectedIds.has(id))
    : activeProgram ? [activeProgram] : [];
  const programs = candidates.filter(({ installed }) => installed === true);
  return { programs, skipped: candidates.length - programs.length };
}
