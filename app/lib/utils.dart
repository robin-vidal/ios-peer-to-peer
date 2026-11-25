String spaceText(String text, int letterPerBlock) {
  StringBuffer res = StringBuffer();
  var i = letterPerBlock;
  for (; i < text.length; i += letterPerBlock) {
    res.write(text.substring(i - letterPerBlock, i));
    res.write(' ');
  }

  res.write(text.substring(i - letterPerBlock));

  return res.toString();
}
