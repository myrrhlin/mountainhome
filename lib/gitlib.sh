#! /bin/bash

# a library of useful bash functions for interacting with git
# mhamlin
# last revised 140922

function gitlib_synopsis() {
cat << EOD
 $ branch_exists foo && echo "yes"
 $ branch_exists master && echo "yes"
 yes
 $ repo_exists && echo "on branch \$(current_branch)"
 on branch handle-features
 $ echo "HEAD is \$(current_sha1) with message '\$(current_commit_msg)', \$(commits_ahead) commits ahead of origin"
 HEAD is b52b71d with message 'WiP-handle-features', 3 commits ahead of origin
 $ commits_ahead
 3
 $ unstaged_changes_exist && git commit -a -m WiP
 [handle-features 4697e96] WiP
 1 files changed, 18 insertions(+), 3 deletions(-)

 $ branch_exists handle-features && gco handle-features
No unsaved changes.
Switched to branch 'handle-features'
Your branch is ahead of 'origin/handle-features' by 3 commits.
Unstaged changes after reset:
M   t/lib/LW/Billing/Master/Test.pm

EOD
}

# TODO:  all functions need to deal well with floating head
#
#

E_BADARGS=85   # bad arguments to a function
E_ABORT=86     # action refused, consequences uncertain
E_INSANE=99    # a sanity check failed

E_NOREPO=3     # no git repo detected in path
E_CONFLICT=4   # a merge/rebase/cherry-pick conflict was encounted, requires a human

# ================================================================
# boolean functions, can be evaluated directly for truth aka success(0)

REMOTE=origin

# returns true (0) if a repo contains current path
function repo_exists() {
    git status --porcelain 1> /dev/null
}
# returns true (0) if modified files have been staged (git add) but not committed
function staged_changes_exist() {
    git status --porcelain | grep -qc '^M '
}
# returns true (0) if modified files that have not been staged (git add)
function unstaged_changes_exist() {
    git status --porcelain | grep -qc '^ M'
}
# returns true (0) if a given branch name exists, false(1) otherwise
function branch_exists() {
    [ -z "$1" ] && exit $E_BADARGS
    # multiple matches prevented by anchoring both ends
    # exit status of grep is success (0) if lines found
    git branch --no-color 2> /dev/null | grep -qc "^[ *] $1$"
}
function branch_exists_remote() {
    local branch="$1"
    [ -z "$branch" ] && branch=$(current_branch)
    git branch -r --no-color 2> /dev/null | grep -qc "^  $REMOTE/$branch$"
}

# ================================================================
# informational functions, outputting a piece of data, capture with $()

# outputs the current branch name... what happens in floating HEAD?
function current_branch() {
    git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}
# outputs the sha1 of the current HEAD
function current_sha1() {
    git log -n1 --oneline --no-color | cut -d' ' -f1
}
# outputs the msg of the current HEAD's commit message
function current_commit_msg() {
    git log -n1 --oneline --no-color | cut -d' ' --complement -f1
}
# outputs the number of commits ahead of origin the current branch is
function commits_ahead() {
    local branch="$1"
    [ -z "$branch" ] && branch=$(current_branch)
    [ -z "$branch" ] && exit $E_BADARGS
    git log --oneline $REMOTE/$branch.. | wc -l
}

# ================================================================
# action functions, performing a specific task

function gsuspend() {
	if unstaged_changes_exist || staged_changes_exist
	then echo Saving uncommitted work as WiP commit.
		git commit -a -m WiP-$(current_branch)
	else echo No unsaved changes.
	fi
}
function gresume() {
	git reset --soft HEAD^ && git reset
}
function greb() {
	if ! branch_exists_remote
	then echo Branch is local only.  No remote branch to rebase upon.
		# never pushed to origin... how to know what it was based off?
		exit $E_ABORT
	fi
	gsuspend
	git rebase -i $REMOTE/$(current_branch)
}
# needs git-bash-completion...
function gco() {
	# doesnt deal well with floating HEAD.
	local branch="$1"
	[ -z "$branch" ] && exit $E_BADARGS
	branch_exists "$branch" || exit $E_BADARGS
	# short-circuit a no-op:
	[ "$branch" = $(current_branch) ] && return 0
	gsuspend
	git checkout "$branch"
	if [[ $(current_commit_msg) == WiP* ]]
	then echo "Resuming previous work (resetting WiP commit)"
		gresume
	fi
}

# resets branch back $1 commits (keeping the code, not the commits)
# aborts if that reset would cross a merge
function soft_reset_n() {
    local npop="$1"
    [ -z "$npop" ] && npop=0
    [ "$npop" -eq 0 ] && exit $E_BADARGS
    if ! git log --oneline --merges HEAD~$npop.. | wc -l 1> /dev/null
    then echo "found a merge, cannot reset past that"
        # unsure code can reliably find correct parent when resetting
        exit E_ABORT
    fi
    git reset --soft HEAD~$npop && git reset
}

# show commits in git branch that aren't in your current branch
function gbin {
    echo branch \($1\) has these commits and \($current_branch\) does not
    git log ..$1 --no-merges --format='%h | %an | %ad | %s' --date=local
}

# show commits in your current branch that aren't in a specified branch
function gbout {
	local dbranch="$1"
	branch_exists $dbranch || exit E_BADARGS
    echo branch \($(current_branch)\) has these commits and \($dbranch\) does not
    git log $1.. --no-merges --format='%h | %an | %ad | %s' --date=local
}

