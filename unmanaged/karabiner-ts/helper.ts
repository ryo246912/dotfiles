export function toIfVariable(name: string, value: string | number | boolean) {
  return { type: "variable_if" as const, name: name, value: value };
}

export function toUnlessVariable(name: string, value: string | number | boolean) {
  return { type: "variable_unless" as const, name: name, value: value };
}
