import { Ok, Error as GleamError } from "../../gleam.mjs";

export function get_env(name) {
  const value = process.env[name];
  return value === undefined ? new GleamError(undefined) : new Ok(value);
}
