# Apple ships com.apple.atrun disabled and SIP keeps its plist read-only, so
# `at` only runs its queued jobs if the same binary runs under our own label.
{ ... }:
{
  launchd.daemons.atrun.serviceConfig = {
    ProgramArguments = [ "/usr/libexec/atrun" ];
    StartInterval = 30;
  };
}
