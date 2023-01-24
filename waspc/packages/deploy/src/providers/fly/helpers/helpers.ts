import { Command } from 'commander'
import { exit } from 'process'
import { $, cd, ProcessOutput, Shell } from 'zx'
import fs from 'fs'
import path from 'node:path'

export function isYes(str: string): boolean {
  return str.trim().toLowerCase().startsWith('y')
}

export function ensureWaspDirLooksRight(thisCommand: Command) {
  if (!fs.existsSync(path.join(thisCommand.opts().waspDir, '.wasproot'))) {
    waspSays('The supplied Wasp directory does not appear to be a valid Wasp project.')
    waspSays('Please double check your path.')
    exit(1)
  }
}

export function buildDirExists(waspDir: string): boolean {
  return fs.existsSync(path.join(waspDir, '.wasp', 'build'))
}

export function cdToServerBuildDir(waspDir: string) {
  cd(path.join(waspDir, '.wasp', 'build'))
}

export function cdToClientBuildDir(waspDir: string) {
  cd(path.join(waspDir, '.wasp', 'build', 'web-app'))
}

export function ensureDirsAreAbsolute(thisCommand: Command) {
  if (thisCommand.opts().waspDir && !path.isAbsolute(thisCommand.opts().waspDir)) {
    waspSays('The Wasp dir path must be absolute.')
    exit(1)
  }

  if (thisCommand.opts().tomlDir && !path.isAbsolute(thisCommand.opts().tomlDir)) {
    waspSays('The toml dir path must be absolute.')
    exit(1)
  }
}

// Promises are eager and start running right when created.
// This lets us create a promise that will won't execute right away.
// Additionally, like a normal promise, it can still be awaited many times
// but only runs to completion once.
export function lazyInit<Type>(fn: () => Promise<Type>) {
  let prom: Promise<Type> | undefined = undefined
  return () => prom = (prom || fn())
}

// For some reason, the colors from the chalk package wouldn't
// show up when run as a subprocess by the Wasp CLI. This works.
export function waspSays(str: string) {
  console.log("🚀 \x1b[33m " + str + " \x1b[0m")
}

export function displayWaspRocketImage() {
  // Escaping backslashes makes it look weird here, but it works in console.
  const asciiArt = `
  Credits: Modified version of ascii art bee by sjw, rocket by unknown.

                    __
                   // \\
                   \\\\_/ //
             _    -(||)(')
            \\ \\____///_____
   #########[==__DEPLOYED__}
            /_/

  `
  console.log(asciiArt)
}

export function getCommandHelp(command: Command): string {
  return trimUsage(command.helpInformation())
}

function trimUsage(usage: string): string {
  return usage.split(/[\r\n]+/)[0].replace('Usage: ', '').replace(' [options]', '')
}

export async function silence(cmd: ($hh: Shell) => Promise<ProcessOutput>): Promise<ProcessOutput> {
  const verboseSetting = $.verbose
  $.verbose = false
  const proc = await cmd($)
  $.verbose = verboseSetting
  return proc
}
