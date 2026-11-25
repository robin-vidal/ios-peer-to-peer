/*
Groups characters of `text` in group of size `letterPerBlock`
Ex: groupCharacters("a1b2c3d4e5f60718", 4)  →  A1B2 C3D4 E5F6 0718
*/
String groupCharacters(String text, int letterPerBlock) {
  StringBuffer res = StringBuffer();
  var i = letterPerBlock;
  for (; i < text.length; i += letterPerBlock) {
    res.write(text.substring(i - letterPerBlock, i));
    res.write(' ');
  }

  res.write(text.substring(i - letterPerBlock));

  return res.toString();
}
