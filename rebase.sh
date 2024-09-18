#!/usr/bin/env bash

remotes=(
	'upstream https://github.com/helix-editor/helix.git'
	'EpocSquadron https://github.com/EpocSquadron/helix.git'
	'JeftavanderHorst https://github.com/JeftavanderHorst/helix.git'
	'Philipp-M https://github.com/Philipp-M/helix.git'
	'SoraTenshi https://github.com/SoraTenshi/helix.git'
	'askreet https://github.com/askreet/helix.git'
	'dead10ck https://github.com/dead10ck/helix.git'
	'ontley https://github.com/ontley/helix.git'
	'pascalkuthe https://github.com/pascalkuthe/helix.git'
	'pickfire https://github.com/pickfire/helix.git'
	'the-mikedavis https://github.com/the-mikedavis/helix.git'
	'xJonathanLEI https://github.com/xJonathanLEI/helix.git'
)

branches=(
	'4493 SoraTenshi/colored-indent-guides'
	# '2857 the-mikedavis/md-rainbow-highlights'
	# '6118 SoraTenshi/sticky-context'
	# '6436 askreet/lsp-command-feedback'
	'6470 pickfire/default-comment'
	'3799 EpocSquadron/epocsquadron/move-default-comment-toggle-binding-to-pound'
	# '9801 upstream/snippet_placeholder'
	'7269 dead10ck/auto-pair-delete'
	'8147 JeftavanderHorst/subwords'
	'2608 Philipp-M/path-completion'
)

fetch="true"
edit="false"
while [ $# -gt 0 ]; do
	case "$1" in
		--no-fetch)
			fetch="false"
			;;
		--edit)
			edit="true"
			;;
	esac
	shift
done

cd "$(dirname "$0")"
selfName=$(basename "$0")
self=$(<"$selfName")
workflow=$(<.github/workflows/build-driver.yaml)

function log() {
	echo -e "\n\033[7m$1\033[0m\n"
}

function subshell() {
	log "$1"

	fish -iC 'function cancel; exit 2; end; function rerere-edit; hx (git rerere remaining); end'

	if [ $? = 2 ]; then
		git merge --abort 2>/dev/null
		git cherry-pick --abort 2>/dev/null
		exit 1
	fi
}

if [ "$fetch" = true ]; then
	for remote in "${remotes[@]}"; do
		remote=($remote)
		git remote add ${remote[@]} 2>/dev/null
		echo "Fetching ${remote[0]}"
		git fetch ${remote[0]}
	done
fi

git switch driver
git reset --hard upstream/master

echo "$self" > "$selfName"
rm .github/workflows/*
echo "$workflow" > .github/workflows/build-driver.yaml
rm book/src/generated/*

git add "$selfName" .github/workflows book/src/generated
git commit -m 'Set up driver branch' || exit

for branch in "${branches[@]}"; do
	branch=($branch)
	pr="${branch[0]}"
	branch=${branch[1]}

	log "Merging $branch"
	git merge --no-ff --no-edit -m "Merge $pr ($branch)" "$branch"

	if [ -e .git/MERGE_HEAD -o "$edit" = true ]; then
		if [ -n "$(git rerere remaining)" ]; then
			subshell "Exit after resolving conflicts. $(git rerere remaining | wc -l) file(s) not resolved by git-rerere"
		elif [ "$edit" = true ]; then
			subshell "Exit after editting"
		fi

		git add --update
		git commit --no-edit --cleanup=strip
	fi
done

HELIX_DISABLE_AUTO_GRAMMAR_BUILD=true cargo check
git add Cargo.lock
subshell "Exit after fixing build errors"
git add --update
git commit -m 'Fix merge'

log Done
