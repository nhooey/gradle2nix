# shellcheck shell=bash disable=SC2206,SC2155

remove_option_and_value() {
    local option_to_remove="$1"
    local -n truncated_array="$2"
    local new_array=()
    local i=0

    while [ $i -lt ${#truncated_array[@]} ]; do
        if [ "${truncated_array[$i]}" = "$option_to_remove" ]; then
            echo "remove_option_and_value: Deleting: [${truncated_array[$i]}] [${truncated_array[$i+1]}]"
            i=$((i + 2))
        else
            new_array+=("${truncated_array[$i]}")
            i=$((i + 1))
        fi
    done

    # Replace the original array with the filtered one
    truncated_array=("${new_array[@]}")
}

print_array_inline() {
    local -n print_array="$1"
    printf "[%s] " "${print_array[@]}"
    echo  # Add newline at the end
}

fix_flags_array() {
    local -n build_phase="$1"
    local -n fix_array="$2"

    echoCmd "${build_phase} flags" "${fix_array[@]}"
    remove_option_and_value '--console' fix_array
    echoCmd "${build_phase} flags (- --console <value>):" "${fix_array[@]}"
    fix_array+=("--continue")
    echoCmd "${build_phase} flags (+ --continue):" "${fix_array[@]}"
}

gradleConfigurePhase() {
    runHook preConfigure

    if ! [[ -v enableParallelBuilding ]]; then
        enableParallelBuilding=1
        echo "gradle: enabled parallel building"
    fi

    if ! [[ -v enableParallelChecking ]]; then
        enableParallelChecking=1
        echo "gradle: enabled parallel checking"
    fi

    if ! [[ -v enableParallelInstalling ]]; then
        enableParallelInstalling=1
        echo "gradle: enabled parallel installing"
    fi

    export GRADLE_USER_HOME="$(mktemp -d)"

    if [ -n "$gradleInitScript" ]; then
        if [ ! -f "$gradleInitScript" ]; then
            echo "gradleInitScript is not a file path: $gradleInitScript"
            exit 1
        fi
        mkdir -p "$GRADLE_USER_HOME/init.d"
        ln -s "$gradleInitScript" "$GRADLE_USER_HOME/init.d"
    fi

    runHook postConfigure
}

gradleBuildPhase() {
    runHook preBuild

    if [ -z "${gradleBuildFlags:-}" ] && [ -z "${gradleBuildFlagsArray[*]}" ]; then
        echo "gradleBuildFlags is not set, doing nothing"
    else
        local flagsArray=(
            $gradleFlags "${gradleFlagsArray[@]}"
            $gradleBuildFlags "${gradleBuildFlagsArray[@]}"
        )

        if [ -n "$enableParallelBuilding" ]; then
            flagsArray+=(--parallel --max-workers ${NIX_BUILD_CORES})
        else
            flagsArray+=(--no-parallel)
        fi

        fix_flags_array 'buildBuildPhase' flagsArray

        gradle "${flagsArray[@]}"
    fi

    runHook postBuild
}

gradleCheckPhase() {
    runHook preCheck

    if [ -z "${gradleCheckFlags:-}" ] && [ -z "${gradleCheckFlagsArray[*]}" ]; then
        echo "gradleCheckFlags is not set, doing nothing"
    else
        local flagsArray=(
            $gradleFlags "${gradleFlagsArray[@]}"
            $gradleCheckFlags "${gradleCheckFlagsArray[@]}"
            ${gradleCheckTasks:-check}
        )

        if [ -n "$enableParallelChecking" ]; then
            flagsArray+=(--parallel --max-workers ${NIX_BUILD_CORES})
        else
            flagsArray+=(--no-parallel)
        fi

        fix_flags_array 'buildCheckPhase' flagsArray

        gradle "${flagsArray[@]}"
    fi

    runHook postCheck
}

gradleInstallPhase() {
    runHook preInstall

    if [ -z "${gradleInstallFlags:-}" ] && [ -z "${gradleInstallFlagsArray[*]}" ]; then
        echo "gradleInstallFlags is not set, doing nothing"
    else
        local flagsArray=(
            $gradleFlags "${gradleFlagsArray[@]}"
            $gradleInstallFlags "${gradleInstallFlagsArray[@]}"
        )

        if [ -n "$enableParallelInstalling" ]; then
            flagsArray+=(--parallel --max-workers ${NIX_BUILD_CORES})
        else
            flagsArray+=(--no-parallel)
        fi

        fix_flags_array 'buildInstallPhase' flagsArray

        gradle "${flagsArray[@]}"
    fi

    runHook postInstall
}

if [ -z "${dontUseGradleConfigure-}" ] && [ -z "${configurePhase-}" ]; then
    configurePhase=gradleConfigurePhase
fi

if [ -z "${dontUseGradleBuild-}" ] && [ -z "${buildPhase-}" ]; then
    buildPhase=gradleBuildPhase
fi

if [ -z "${dontUseGradleCheck-}" ] && [ -z "${checkPhase-}" ]; then
    checkPhase=gradleCheckPhase
fi

if [ -z "${dontUseGradleInstall-}" ] && [ -z "${installPhase-}" ]; then
    installPhase=gradleInstallPhase
fi
