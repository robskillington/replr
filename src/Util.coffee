
class Util
  constructor: ()->


Util::isInt = (number)->
  return false if typeof number != 'number'
  str = String(number)
  n = ~~Number(str)
  return String(n) == str

module.exports = Util
