#!/usr/bin/env bash
# Development probe: runs a throwaway copy of the plasmoid with extra QML injected
# into the root PlasmoidItem (e.g. a Timer that drives backends or grabs images).
#   ./probe.sh <snippet.qml> <workdir> [seconds]
# Inside the snippet, `root` is the PlasmoidItem and `probeDir` is <workdir>.
set -euo pipefail

cd "$(dirname "$0")"
SNIPPET=$(realpath "$1")
WORK=$(realpath -m "$2")
SECONDS_TO_RUN=${3:-12}
PROBE_ID=local.plasmalogo.probe

rm -rf "$WORK/pkg"
mkdir -p "$WORK"
cp -r package "$WORK/pkg"
sed -i "s/\"Id\": \"[^\"]*\"/\"Id\": \"$PROBE_ID\"/" "$WORK/pkg/metadata.json"
# Translations are looked up by domain (plasma_applet_<Id>): follow the new Id.
for mo in "$WORK"/pkg/contents/locale/*/LC_MESSAGES/plasma_applet_*.mo; do
    [ -e "$mo" ] && mv "$mo" "$(dirname "$mo")/plasma_applet_$PROBE_ID.mo"
done

# Lines starting with "import" in the snippet go to the top of main.qml.
python3 - "$WORK/pkg/contents/ui/main.qml" "$SNIPPET" "$WORK" <<'EOF'
import sys
main, snippet, work = sys.argv[1:]
src = open(main).read()
lines = open(snippet).read().splitlines(keepends=True)
imports = "".join(l for l in lines if l.startswith("import "))
body = "".join(l for l in lines if not l.startswith("import "))
extra = f'    readonly property string probeDir: "{work}"\n' + body
i = src.rindex('}')
src = src[:i] + extra + src[i:]
j = src.index("PlasmoidItem {")
open(main, 'w').write(src[:j] + imports + "\n" + src[j:])
EOF

if kpackagetool6 --type Plasma/Applet --show "$PROBE_ID" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$WORK/pkg" >/dev/null
else
    kpackagetool6 --type Plasma/Applet --install "$WORK/pkg" >/dev/null
fi

# plasmawindowed ignores Qt.quit(), so the run ends with "timeout"; do not leave
# a core dump (and a DrKonqi crash report) behind every time.
ulimit -c 0
QML_DISABLE_DISK_CACHE=1 QT_FORCE_STDERR_LOGGING=1 QT_LOGGING_RULES="js.debug=true;qml.debug=true" \
    QT_QPA_PLATFORM=${PROBE_PLATFORM:-offscreen} timeout "$SECONDS_TO_RUN" plasmawindowed "$PROBE_ID" > "$WORK/log.txt" 2>&1 || true
kpackagetool6 --type Plasma/Applet --remove "$PROBE_ID" >/dev/null

grep -vE 'QFontDatabase|QGuiApplication::font|QPixmap: Must|^qml: 0$' "$WORK/log.txt" || true
