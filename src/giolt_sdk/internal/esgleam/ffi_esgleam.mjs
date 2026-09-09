// Modified from Enderchief/esgleam - see https://github.com/withgiolt/esgleam
// @ts-check
//
// Only the platform detection used by `esgleam/mod/platform` is kept here.
// Downloading and running esbuild lives in `../ffi_esbuild.mjs`.
import { default as process } from "node:process";
import {
  Android,
  Win32,
  Linux,
  Darwin,
  Solaris,
  Freebsd,
  Openbsd,
  Arm,
  Arm64,
  Ia32,
  Ppc64,
  X64,
  // @ts-expect-error
} from "./esgleam/mod/platform.mjs";
// @ts-expect-error
import { Ok, Error } from "../../../gleam.mjs";

/** @type {Partial<Record<NodeJS.Platform, () => unknown>>} */
const platform_map = {
  android: () => new Android(),
  darwin: () => new Darwin(),
  freebsd: () => new Freebsd(),
  linux: () => new Linux(),
  openbsd: () => new Openbsd(),
  sunos: () => new Solaris(),
  win32: () => new Win32(),
};

export function get_os() {
  const platform = process.platform;
  const res = platform_map[platform]?.();
  if (res) return new Ok(res);
  return new Error(undefined);
}

/** @type {Partial<Record<NodeJS.Architecture, () => unknown>>} */
const arch_map = {
  arm: () => new Arm(),
  arm64: () => new Arm64(),
  ia32: () => new Ia32(),
  ppc64: () => new Ppc64(),
  x64: () => new X64(),
};

export function get_arch() {
  const arch = process.arch;
  const res = arch_map[arch]?.();
  if (res) return new Ok(res);
  return new Error(undefined);
}
