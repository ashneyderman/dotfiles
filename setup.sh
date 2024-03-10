echo "Check if brew is installed"

if test ! $(which brew); then
  echo "Please, install brew"
  exit 1
else
  echo "Brew is installed"
fi

if test ! $(which gun); then
  brew install gum
fi

gum spin --title="Installing extra fonts" cp ./fonts/*.ttf ~/Library/Fonts/


