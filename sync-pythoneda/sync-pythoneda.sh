#!/usr/bin/env dry-wit
# Copyright 2023-today Automated Computing Machinery S.L.
# Distributed under the terms of the GNU General Public License v3

DW.import file;
DW.import nix-flake;
DW.import git;

# fun: main
# api: public
# txt: Main logic. Gets called by dry-wit.
# txt: Returns 0/TRUE always, but may exit due to errors.
# use: main
function main() {

  local _projects=( \
    "pythoneda-shared-pythoneda/banner" \
    "pythoneda-shared-pythoneda/domain" \
    "pythoneda-shared-pythoneda/infrastructure" \
    "pythoneda-shared-artifact/events" \
    "pythoneda-shared-artifact/artifact-events" \
    "pythoneda-shared-git/shared" \
    "pythoneda-shared-nix-flake/shared" \
    "pythoneda-shared-artifact/shared" \
    "pythoneda-shared-pythoneda/application" \
    "pythoneda-shared-artifact/artifact-shared" \
    "pythoneda-shared-artifact/events-infrastructure" \
    "pythoneda-shared-artifact/artifact-events-infrastructure" \
    "pythoneda-shared-artifact/artifact-infrastructure" \
    "pythoneda-shared-artifact/infrastructure" \
    "pythoneda-shared-artifact/application" \
    "pythoneda-shared-code-requests/shared" \
    "pythoneda-shared-code-requests/events" \
    "pythoneda-shared-code-requests/events-infrastructure" \
    "pythoneda-shared-code-requests/jupyterlab" \
    "pythoneda-shared-artifact/code-events" \
    "pythoneda-shared-artifact/code-events-infrastructure" \
    "pythoneda-realm-rydnr/events" \
    "pythoneda-realm-rydnr/events-infrastructure" \
    "pythoneda-realm-rydnr/realm" \
    "pythoneda-realm-rydnr/infrastructure" \
    "pythoneda-realm-rydnr/application" \
    "pythoneda-realm-unveilingpartner/realm" \
    "pythoneda-realm-unveilingpartner/infrastructure" \
    "pythoneda-realm-unveilingpartner/application" \
    "pythoneda-sandbox/python-dep" \
    "pythoneda-sandbox/python" \
    "pythoneda-sandbox-artifact/python-dep" \
    "pythoneda-sandbox-artifact/python" \
    "pythoneda-sandbox-artifact/python-artifact" \
    "pythoneda-sandbox-artifact/python-infrastructure" \
    "pythoneda-sandbox-artifact/python-application" \
    "pythoneda-artifact/git" \
    "pythoneda-artifact/git-infrastructure" \
    "pythoneda-artifact/git-application" \
    "pythoneda-artifact/nix-flake" \
    "pythoneda-artifact/nix-flake-infrastructure" \
    "pythoneda-artifact/nix-flake-application" \
    "pythoneda-artifact/code-request-infrastructure" \
    "pythoneda-artifact/code-request-application" \
    "pythoneda-shared-pythoneda-artifact/domain" \
    "pythoneda-shared-pythoneda-artifact/domain-infrastructure" \
    "pythoneda-shared-pythoneda-artifact/domain-application" \
    );

  # from sync-pythoneda-project.sh -vv -h
  local -i _skippedProject=24;

  resolveVerbosity;
  local _commonArgs=(${RESULT});
  if ! isEmpty "${GITHUB_TOKEN}"; then
    _commonArgs+=("-t" "${GITHUB_TOKEN}");
  fi
  _commonArgs+=("${_commonArgs[@]}" "-R" "${RELEASE_NAME}");
  if ! isEmpty "${COMMIT_MESSAGE}"; then
    _commonArgs+=("-c" "${COMMIT_MESSAGE}");
  fi
  if ! isEmpty "${TAG_MESSAGE}"; then
    _commonArgs+=("-m" "${TAG_MESSAGE}");
  fi
  if ! isEmpty "${GPG_KEY_ID}"; then
    _commonArgs+=("-g" "${GPG_KEY_ID}");
  fi
  local _updatedProjects=();
  local _upToDateProjects=();
  local _failedProjects=();
  local _project;
  local _defOwner;
  local _repo;
  local -i _rescode;
  local _output;
  local -i _index=0;
  local -i _totalProjects=${#_projects[@]};

  createTempFile;
  local _syncPythonedaProjectOutput="${RESULT}";

  local _origIFS="${IFS}";
  IFS="${DWIFS}";
  for _project in "${_projects[@]}"; do
    IFS="${_origIFS}";
    if extract_owner "${_project}"; then
      _defOwner="${RESULT}-def";
    else
      exitWithErrorCode CANNOT_EXTRACT_THE_OWNER_OF_PROJECT "${_project}";
    fi
    if extract_repo "${_project}"; then
      _repo="${RESULT}";
    else
      exitWithErrorCode CANNOT_EXTRACT_THE_REPOSITORY_NAME_OF_PROJECT "${_project}";
    fi
    _index=$((_index + 1));
    logInfo "[${_index}/${_totalProjects}] Processing ${_defOwner}/${_repo}";
    "${SYNC_PYTHONEDA_PROJECT}" "${_commonArgs[@]}" -p "${ROOT_FOLDER}/${_defOwner}/${_repo}" | tee "${_syncPythonedaProjectOutput}";
    _rescode=$?;
    if isTrue ${_rescode}; then
      _updatedProjects+=("${_defOwner}/${_repo}");
    elif areEqual ${_rescode} ${_skippedProject}; then
      _upToDateProjects+=("${_defOwner}/${_repo}");
    else
      logInfo "Error processing ${_defOwner}/${_repo}";
      _output="$(<"${_syncPythonedaProjectOutput}")";
      if ! isEmpty "${_output}"; then
        logDebug "${_output}";
      fi
      _failedProjects+=("${_defOwner}/${_repo}");
      continue;
    fi
    IFS="${_origIFS}";
  done
  IFS="${_origIFS}";

  if isNotEmpty "${_failedProjects[@]}"; then
    logInfo -n "Number of projects that couldn't be updated";
    logInfoResult SUCCESS "${#_failedProjects[@]}";
    IFS="${DWIFS}";
    for _project in "${_failedProjects[@]}"; do
      IFS="${_origIFS}";
      logInfo "${_project}";
    done
    IFS="${_origIFS}";
  fi

  if isNotEmpty "${_upToDateProjects[@]}"; then
    logInfo -n "Number of projects already up to date";
    logInfoResult SUCCESS "${#_upToDateProjects[@]}";
    IFS="${DWIFS}";
    for _project in "${_upToDateProjects[@]}"; do
      IFS="${_origIFS}";
      logInfo "${_project}";
    done
    IFS="${_origIFS}";
  fi

  if isNotEmpty "${_updatedProjects[@]}"; then
    logInfo -n "Number of projects updated";
    logInfoResult SUCCESS "${#_updatedProjects[@]}";
    IFS="${DWIFS}";
    for _project in "${_updatedProjects[@]}"; do
      IFS="${_origIFS}";
      logInfo "${_project}";
    done
    IFS=','
    echo "[ ${_updatedProjects[*]} ]"
    IFS="${_origIFS}";
  fi
}

# fun: extract_owner project
# api: public
# txt: Extracts the owner from given project name.
# opt: project: The project name.
# txt: Returns 0/TRUE if the owner could be extracted; 1/FALSE otherwise.
# txt: If the function returns 0/TRUE, the variable RESULT will contain the owner.
# use: if extract_owner "pythoneda-shared-pythoneda/domain"; then echo "Owner: ${RESULT}"; fi
function extract_owner() {
  local _project="${1}";
  checkNotEmpty project "${_project}" 1;

  local -i _rescode=${FALSE};
  local _result;

  _result="$(echo "${_project}" | cut -d '/' -f 1 2>/dev/null)";
  _rescode=$?;

  if isEmpty "${_result}"; then
     _rescode=${FALSE};
  fi
  if isTrue ${_rescode}; then
    export RESULT="${_result}";
  fi

  return ${_rescode};
}

# fun: extract_repo project
# api: public
# txt: Extracts the repository from given project name.
# opt: project: The project name.
# txt: Returns 0/TRUE if the repository could be extracted; 1/FALSE otherwise.
# txt: If the function returns 0/TRUE, the variable RESULT will contain the repository name.
# use: if extract_repo "pythoneda-shared-pythoneda/domain"; then echo "Repo: ${RESULT}"; fi
function extract_repo() {
  local _project="${1}";
  checkNotEmpty project "${_project}" 1;

  local -i _rescode=${FALSE};
  local _result;

  _result="$(command echo "${_project}" | command cut -d '/' -f 2 2>/dev/null)";
  _rescode=$?;
  if isEmpty "${_result}"; then
     _rescode=${FALSE};
  fi
  if isTrue ${_rescode}; then
    export RESULT="${_result}";
  fi

  return ${_rescode};
}

## Script metadata and CLI settings.
setScriptDescription "Synchronizes PythonEDA projects";
setScriptLicenseSummary "Distributed under the terms of the GNU General Public License v3";
setScriptCopyright "Copyleft 2023-today Automated Computing Machinery S.L.";

DW.getScriptName;
SCRIPT_NAME="${RESULT}";
addCommandLineFlag "rootFolder" "r" "The root folder of PythonEDA definition projects" MANDATORY EXPECTS_ARGUMENT;
addCommandLineFlag "githubToken" "t" "The github token" OPTIONAL EXPECTS_ARGUMENT;
addCommandLineFlag "releaseName" "R" "The release name" MANDATORY EXPECTS_ARGUMENT;
addCommandLineFlag "gpgKeyId" "g" "The id of the GPG key" OPTIONAL EXPECTS_ARGUMENT;
addCommandLineFlag "commitMessage" "c" "The commit message" OPTIONAL EXPECTS_ARGUMENT "Commit created with ${SCRIPT_NAME}";
addCommandLineFlag "tagMessage" "m" "The tag message" OPTIONAL EXPECTS_ARGUMENT "Tag created with ${SCRIPT_NAME}";

checkReq jq;
checkReq sed;
checkReq grep;

addError ROOT_FOLDER_DOES_NOT_EXIST "Given root folder for definition projects does not exist:";
addError PROJECT_FOLDER_DOES_NOT_EXIST "Project folder does not exist:"
addError CANNOT_EXTRACT_THE_OWNER_OF_PROJECT "Cannot extract the owner of project:";
addError CANNOT_EXTRACT_THE_REPOSITORY_NAME_OF_PROJECT "Cannot extract the repository name of project:";
addError CANNOT_UPDATE_LATEST_INPUTS "Cannot update inputs to its latest versions in";
addError CANNOT_RELEASE_TAG "Cannot create a new release tag in";

## deps
export SYNC_PYTHONEDA_PROJECT="__SYNC_PYTHONEDA_PROJECT__";
if areEqual "${SYNC_PYTHONEDA_PROJECT}" "__SYNC_PYTHONEDA_PROJECT__"; then
  export SYNC_PYTHONEDA_PROJECT="sync-pythoneda-project.sh";
fi

function dw_check_rootFolder_cli_flag() {
  if ! fileExists "${ROOT_FOLDER}"; then
    exitWithErrorCode ROOT_FOLDER_DOES_NOT_EXIST "${ROOT_FOLDER}"
  fi
}
# vim: syntax=sh ts=2 sw=2 sts=4 sr noet
