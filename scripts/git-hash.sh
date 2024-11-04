#! /bin/bash

# $exec OUTPUT-NAME USES-LIST
# Generates a string literal encoding the git repo:
# $UpstreamURL($RemoteBranch) $LocalBranch:$Hash [$N ahead]-opt dirty-opt
# UpstreamURL is either a local pathname, or a git repo


set -e

get-hash () {
    local dir=$1
    local hd="$(git -C $dir rev-parse --short=8 HEAD 2>/dev/null)"
    local st="$(git -C $dir status --porcelain=v1 --branch)"
    local info=$(echo "$st" | head -1)
    local dirty=false
    test "$st" != "$info" && dirty=true
    local warning=false
    # info is something like '## main...origin/main [ahead 3]'
    # or '## HEAD (no branch)' for a detached
    if test "$info" = "## HEAD (no branch)" ; then
	# see if we're coincident with a remote branch or tag
	local branches="$(git -C $dir log --pretty=format:%d -1 | sed -e 's/[(),]//g' -e 's/: /:/g')"
	local branch
	for branch in $branches ; do
	    case "$branch" in
		origin/*) info="## $hd...$branch" ; break ;;
		tag:*) # have to guess at origin here
		    info="## $hd...origin/${branch#tag:}" ; break ;;
	    esac
	done
    fi
    local upstream=$(echo "$info" | sed 's/.*\.\.\.\([^ ]*\).*/\1/')
    local output remotebranch
    if test "$info" = "$upstream" ; then
	output="$(hostname):$(pwd)"
	remotebranch=""
	warning=true
    elif url=$(git -C $dir remote get-url "${upstream%%/*}" 2>/dev/null) ; then
	output="$url"
	remotebranch="${upstream#*/}"
    else
	output="$(hostname):$(pwd)"
	remotebranch=${upstream}
	warning=true
    fi
    local localbranch="$(echo "$info" | sed 's/## \([^ ]*\) \?.*/\1/')"
    if test "$localbranch" != "$info" ; then
	localbranch="${localbranch%%...*}"
    else
	localbranch=""
    fi
    if test "$remotebranch" && test "$remotebranch" != "${localbranch}" ; then
	output+="($remotebranch)"
    fi
    output+=" "
    if test "${localbranch}"; then
	output+="${localbranch%}:"
    fi
    output+="$hd"

    local ahead=$(echo "$info" | sed 's/.*\[ahead \([0-9]\+\)].*/\1/')
    if test "$info" != "$ahead" ; then
	warning=true
	if test "$upstream" &&
		org=$(git -C $dir rev-parse --short=8 "$upstream" 2>/dev/null) ; then
	    output+=" [$org+$ahead]"
	else
	    output+=" [$ahead ahead]"
	fi
    fi
    $dirty && output+=" dirty"
    $dirty && warning=true

    echo "$dir $output"
    if $warning ; then
	echo "*** WARNING: $dir $output IS NOT UPSTREAM ***" 1>&2
    fi
}

get-hash .
for submodule in $(git config --file .gitmodules --get-regexp "\.path$" | cut -d' ' -f2)
do
    get-hash $submodule
done
