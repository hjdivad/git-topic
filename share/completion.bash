


_git_work_on() {
  __gitcomp "$(git-topic-completion work-on 2> /dev/null)"
  return
}

_git_review() {
  __gitcomp "$(git-topic-completion review 2> /dev/null)"
  return
}


_git_done() {
  __gitcomp "$(git-topic-completion done 2> /dev/null)"
  return
}

_git_accept() {
  __gitcomp "$(git-topic-completion accept 2> /dev/null)"
  return
}

_git_reject() {
  __gitcomp "$(git-topic-completion reject 2> /dev/null)"
  return
}

_git_comment() {
  __gitcomp "$(git-topic-completion comment 2> /dev/null)"
  return
}

_git_comments() {
  __gitcomp "$(git-topic-completion comments 2> /dev/null)"
  return
}
