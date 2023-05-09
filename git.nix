{ lib, writeText, makeWrapper, symlinkJoin, git, git-lfs, gitui, delta, ... }:
let
  config = writeText "gitconfig" (lib.generators.toGitINI {
    diff.algorithm = "histogram";
    diff.colorMoved = "default";
    core.pager = "delta";

    interactive.diffFilter = "delta --color-only";
    delta.navigate = true;

    merge.conflictstyle = "diff3";

    filter.lfs = {
      clean = "git-lfs clean -- %f";
      smudge = "git-lfs smudge -- %f";
      process = "git-lfs filter-process";
      required = true;
    };
  });
in symlinkJoin {
  name = "git-with-config-${git.version}";

  paths = [
    (git.override {
      withSsh = true;
      withLibsecret = true;
    })
    delta
    git-lfs
    gitui
  ];

  nativeBuildInputs = [ makeWrapper ];

  passthru.unwrapped = git;

  postBuild = ''
    rm $out/bin/git

    mkdir -p "$out/config"

    cp "${config}" "$out/config/gitconfig"

    makeWrapper "${git}/bin/git" "$out/bin/git" \
       --set GIT_CONFIG_SYSTEM "$out/config/gitconfig"
  '';
}
