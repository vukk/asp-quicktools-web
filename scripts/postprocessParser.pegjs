/*
 * peg.js potassco solver default text to json parser
 * TODO: cleanup by using $str, add E* to all the things... (even after \n maybe)
 */

/* initializer */

{
  function clingoCall(facts) {
    var options = "--outf=2";
    var inputElem = document.getElementById("taInputRules");
    var oldOutput = output; // save old one
    output = "";
    var inputStr = facts.join(". ") + ".\n" + inputElem.value;
    console.log("inputting: ", inputStr);
    Module.ccall('run', 'number', ['string', 'string'], [inputStr, options]);
    console.log("output was: ", output);
    var outJSON = JSON.parse(output);
    var newAnswerset = outJSON["Call"][0]["Witnesses"][0]["Value"].join(" ");
    output = oldOutput; // set it back (this is to avoid problems with sites using clingo)
    return newAnswerset + "\n";
  }

  function extractList(list, index) {
    var result = [], i;

    for (i = 0; i < list.length; i++) {
      if (list[i][index] !== null) {
        result.push(list[i][index]);
      }
    }

    return result;
  }

  function buildList(first, rest, index) {
    return (first !== null ? [first] : []).concat(extractList(rest, index));
  }
}

start
  = triplets:(triplet+) rest:$(skipToAnswer anyLine?) { return triplets.join("") + rest; }

triplet
  = a:skipToAnswer b:answerNumLineNl c:answersetLineNl { return a + b + c; }

skipToAnswer
  = skipped:$((!("Answer: ") anyLineNl)*) { return skipped; }

answerNumLineNl "answer number line"
  = line:$("Answer: " num:posinteger "\n") {return line;}

answersetLineNl "answer set line"
  = first:predicate rest:(S+ predicate)* "\n"
  { var facts = buildList(first, rest, 1);
    return clingoCall(facts); }
  / E* "\n" { return "\n"; }

anyLine
  = all:$([^\n]*) { return all; }
  
anyLineNl
  = all:$(anyLine "\n") { return all; }


/* a single predicate */

predicate "predicate"
  = $(ident "(" arguments ")")

// must have at least 1 argument (no empty predicates or tuples)
arguments
  = first:argument rest:("," S* argument)*

argument
  = pred:$(predicate) { return pred; }
  / tag:$(ident)      { return tag; }
  / num:$(posinteger) { return num; }

/* numbers */

posinteger "positive integer"
  = digits:[0-9]+

// digits:("-"? [0-9]+) doesn't work for some reason, pegjs bug?
integer "integer"
  = sign:"-"? digits:([0-9]+)

/* characters & strings */

// prefix allows default negation e.g. '-predicate(X,Y)'
ident "identifier"
  = $("-"? identStart identChar*)

// allow "_" on the start of idents, since heuristic predicates might be present in the output
identStart
  = [_a-z]i
  / nonascii

identChar
  = [_a-z0-9-]i
  / nonascii

nonascii
  = [\x80-\uFFFF]

E "space or tab"
  = [ \t\f]

S "whitespace"
  = [ \t\r\n\f]
