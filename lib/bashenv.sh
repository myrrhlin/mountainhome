# list most recently changed files only
function lt {
    ls -lt --color=tty "$@" | head
}

# function to preprend to a :-delimited path list env variable
# can also append with final parameter 'after'
# use:   pathpend PERL5LIB ~/perl5/lib/perl5
function pathpend () {
    local var="$1"  # environment variable's name
    if ! env | /bin/egrep -q "^$var=" ; then
        # echo creating a new env variable $var
        eval export $var=$2
    elif ! eval echo "\$$var" | /bin/egrep -q "(^|:)$2($|:)" ; then
        # echo variable $var already existed
        if [ "$3" = "after" ] ; then
            eval $var=\$$var:$2
        else
            eval $var=$2:\$$var
        fi
    fi
}

# report perl module version
function modvers {
    perl -M$1 -E "say '$1 is v ', $1->VERSION"
}

