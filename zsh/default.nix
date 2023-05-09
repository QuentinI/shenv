{ makeWrapper, writeText, symlinkJoin, atuin, coreutils, zoxide, direnv, starship
, nix-index, zsh, zsh-autosuggestions, zsh-fast-syntax-highlighting, zsh-completions, nix-zsh-completions, nix, ... }:
let
  starship' = symlinkJoin {
    name = "starship-with-config-${starship.version}";

    paths = [ starship ];

    nativeBuildInputs = [ makeWrapper ];

    passthru.unwrapped = starship;

    postBuild = ''
      rm $out/bin/starship

      makeWrapper "${starship}/bin/starship" "$out/bin/starship" --set STARSHIP_CONFIG "${./starship.toml}"
    '';
  };

  atuin' = symlinkJoin {
    name = "atuin-with-config-${atuin.version}";

    paths = [ atuin ];

    nativeBuildInputs = [ makeWrapper ];

    passthru.unwrapped = atuin;

    postBuild = ''
      rm $out/bin/atuin

      mkdir -p $out/config

      cp ${./atuin.toml} $out/config/config.toml

      makeWrapper "${atuin}/bin/atuin" "$out/bin/atuin" \
       --set ATUIN_CONFIG_DIR "$out/config"
    '';
  };

  config = writeText "zshrc" ''
    source ${nix-zsh-completions}/share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh
    fpath=(${zsh-completions}/share/zsh/site-functions/ $fpath)
    fpath=(${nix-zsh-completions}/share/zsh/site-functions/ $fpath)
    fpath=(${nix}/share/zsh/site-functions/ $fpath)
  
    ${builtins.readFile ./zshrc.zsh}

    if [ -f ~/.dir_colors ]; then
      eval "$(${coreutils}/bin/dircolors ~/.dir_colors)";
    else
      eval "$(${coreutils}/bin/dircolors)";
    fi

    eval "$(${zoxide}/bin/zoxide init zsh)"
    export _ZO_ECHO=1
    alias j='z'

    eval "$(${direnv}/bin/direnv hook zsh)"
    eval "$(${starship'}/bin/starship init zsh)"
    eval "$(${atuin'}/bin/atuin init zsh --disable-up-arrow)"
    source ${nix-index}/etc/profile.d/command-not-found.sh
    source ${zsh-fast-syntax-highlighting}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh

    _zsh_autosuggest_strategy_atuin() {
      emulate -L zsh
      local prefix="''${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}"
      search=$(atuin search --cmd-only "^$prefix*" --limit 1)
      typeset -g suggestion=$search
    }

    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
    ZSH_AUTOSUGGEST_STRATEGY=(atuin completion)
    source ${zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  '';
in symlinkJoin {
  name = "zsh-with-config-${zsh.version}";

  paths = [ zsh zsh-autosuggestions zoxide starship' direnv coreutils atuin' ];

  nativeBuildInputs = [ makeWrapper ];

  passthru.unwrapped = zsh;

  postBuild = ''
    rm $out/bin/zsh

    mkdir -p "$out/config"

    cp "${config}" "$out/config/.zshrc"

    makeWrapper "${zsh}/bin/zsh" "$out/bin/zsh" \
     --set STARSHIP_CONFIG "${./starship.toml}" \
     --set ZDOTDIR "$out/config" \
     --suffix PATH : "${atuin'}/bin/"
  '';
}

