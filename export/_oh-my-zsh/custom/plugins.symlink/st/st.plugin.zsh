# Super touch
if [ ! -d "$TEMPLATE_DIR" ]; then
    export TEMPLATE_DIR="$HOME/.template"
fi

# param {String} fileName
# param {String} template
function _st_write(){
  local fileName="$1"
  local template="$2"

  echo "$template" >> "$fileName"
}

# Get template by file name
# in folder ~/.templates
#
# param {String} fileName
# return {String} The template string
function _st_getTemplate(){
    local templateDir="$TEMPLATE_DIR"
    local fileName="$1"
    local TEMPLATE=""

    if [ -e "$templateDir" ]; then
      for tmpFileName in $(ls -A "$templateDir"); do
        if [ -e "$templateDir/$tmpFileName" ]; then
          if [ "$tmpFileName" = "$fileName" ];then
            TEMPLATE="$(cat $templateDir/$tmpFileName)"
          fi
        fi
      done
    fi

    echo "$TEMPLATE"
}


# My awesome touch function
function st(){
  local template=""

  for fileName in $@; do
      template="$(_st_getTemplate $fileName)"

      if [ "$template" ]; then
        _st_write $fileName "$template"
      fi
  done

  touch $@
}
