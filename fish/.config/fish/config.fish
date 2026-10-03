# function fish_prompt -d "Write out the prompt"
#     # This shows up as USER@HOST /home/user/ >, with the directory colored
#     # $USER and $hostname are set by fish, so you can just use them
#     # instead of using `whoami` and `hostname`
#     printf '%s@%s %s%s%s > ' $USER $hostname \
#         (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
# end

if status is-interactive # Commands to run in interactive sessions can go here

    fish_config theme choose "catppuccin-mocha"
    # No greeting
    set fish_greeting

    # Use starship
    # useless as something else was here that is now deleted
    # if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    #     cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    # end

    # Aliases
    alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear properly
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    # alias ls 'eza --icons'
    alias pamcan pacman
    alias q 'qs -c ii'
    
end

fish_add_path /home/arindamlegend/.spicetify


if status is-interactive
    # Replace ls with eza (icons + colors)
    abbr -a ls 'eza --icons --group-directories-first'
    abbr -a ll 'eza -l --icons --group-directories-first'
    
    # Replace cat with bat (syntax highlighting)
    abbr -a cat 'bat'
    
    # Fast system monitor
    abbr -a top 'btop'
    
    # CachyOS update shortcut
    abbr -a update 'sudo cachyos-rate-mirrors && yay -Syu'
end


set -gx LANG en_US.UTF-8
