REPO="https://github.com/mr-pennyworth/alfred-extra-pane"
SPARKLE_RELEASES="https://github.com/sparkle-project/Sparkle/releases/download"
APPCAST_XML="appcast.xml"
vSPARKLE="2.6.4"
SPARKLE_DIST_ZIP="Sparkle-$vSPARKLE.tar.xz"
SPARKLE_DIST_URL="$SPARKLE_RELEASES/$vSPARKLE/$SPARKLE_DIST_ZIP"

app_version="$1"
prev_tag="$2"
signing_key_file="$3"
latest_appcast_url="$REPO/releases/download/$prev_tag/$APPCAST_XML"

# Download the sparkle distribution, extract it, and copy the signer binary
# so that we can sign the AlfredExtraPane.app.zip file.
function download_sparkle_dist() {
  if [ ! -d Sparkle ]; then
    wget "$SPARKLE_DIST_URL"
    mkdir -p Sparkle
    tar -xf "$SPARKLE_DIST_ZIP" -C Sparkle
  fi
}

function signature() {
  ./Sparkle/bin/sign_update \
    AlfredExtraPane.app.zip -f "$signing_key_file"
}

function new_appcast_item() {
  cat <<EOF
<item>
  <title>Version ${app_version}</title>
  <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S %z")</pubDate>
  <enclosure
    url="$REPO/releases/download/${app_version}/AlfredExtraPane.app.zip"
    sparkle:version="${app_version}"
    sparkle:shortVersionString="${app_version}"
    $(signature)
    type="application/octet-stream"/>
</item>
EOF
}

# Download the appcast.xml file, then add the new appcast item to it.
# Finally, upload the updated appcast.xml file to the repo.
function update_appcast() {
  rm -f $APPCAST_XML
  wget "$latest_appcast_url"

  head -n6 $APPCAST_XML
  new_appcast_item
  tail -n+7 $APPCAST_XML
}

download_sparkle_dist
update_appcast > appcast.new.xml
mv appcast.new.xml $APPCAST_XML

