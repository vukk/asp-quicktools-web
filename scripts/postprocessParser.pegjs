/*
 * peg.js post processing parser, clingo calls hacked in UGLY
 * TODO: cleanup, add E* to all the things... (even after \n maybe)
 */

/* initializer */

{
  var skippedParts = []; // text in between
  var allAnswerSets = []; // array of answerset arrays
  var wrappedAnswerSets = []; // array of wrapped terms as(Ans,ModelNum)
  var modelCounter = 0;

  function clingoCall(facts) {
    var options = "--outf=2 --out-hide-aux";
    var inputElem = document.getElementById("taInputRules");
    var oldOutput = output; // save old one
    output = "";
    var inputStr = facts.join(". ") + ".\n" + inputElem.value;
    //var inputStr = facts.join(". ") + ".\n";
    console.log("inputting: ", inputStr);
    Module.ccall('run', 'number', ['string', 'string'], [inputStr, options]);
    //output = "{\"Call\":[{\"Witnesses\":[{\"Value\":[\"dev\"]}]}]}"
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


// skipToAnswer, answerNum, answer, <repeatPrevious...>, anyline{0,}
start
  = triplets:(triplet+) rest:$(skipToAnswer anyLine?)
  {
    var returnStr = "";

    // loop over models
    for(var i = 0; i < modelCounter; i++) {
      returnStr += skippedParts[i];

      // call clingo with answerset and all other answersets wrapped
      var input = ["#const asCurrent = "+(i+1), "#const asCount = "+modelCounter];
      Array.prototype.push.apply(input, allAnswerSets[i]);
      Array.prototype.push.apply(input, wrappedAnswerSets);
      console.log('inputting',input);
      // arr.concat(barr) creates a new array
      //var input = allAnswerSets[i].concat(wrappedAnswerSets).concat(modelConsts);
      returnStr += clingoCall(input);
    }

    // add last bit of text
    returnStr += rest;

    return returnStr;
  }

triplet
  = a:skipToAnswer b:answerNumLineNl c:answersetLine "\n"
  {
    skippedParts.push(a + b);
    allAnswerSets.push(c);
    // wrap all terms and push them to wrappedAnswerSets
    for(idx in c) {
      wrappedAnswerSets.push( '_as(' + c[idx] + ',' + (modelCounter+1) + ')' );
    }
    modelCounter = modelCounter + 1;
  }

skipToAnswer
  = skipped:$((!("Answer: ") anyLineNl)*) { return skipped; }

answerNumLineNl "answer number line"
  = line:$("Answer: " num:posinteger "\n") {return line;}

answersetLine "answer set line"
  = E* first:term? rest:(E+ term)* E*
  { return buildList(first, rest, 1); }
  / E* { return []; } // TODO: necessary?

anyLine
  = all:$([^\n]*) { return all; }

anyLineNl
  = all:$(anyLine "\n") { return all; }

term // tuple is not allowed
  = predicate
  / atom:predicateIdent
  / string:aspstring
  / num:number

/* a single predicate */

predicate "predicate"
  = $(predicateIdent "(" arguments ")")

// must have at least 1 argument (no empty predicates or tuples)
arguments
  = first:argument rest:("," E* argument)*

// tuples OK
argument
  = predicate
  / atom:predicateIdent
  / tuple:anontuple
  / string:aspstring
  / num:number

/* tuples */

anontuple
  = "(" E* first:argument rest:("," E* argument)* E* ")"

/* ASP strings */

aspstring "double quoted string"
  = "\"" str:string "\""

/* numbers */

posinteger "positive integer"
  = digits:[0-9]+

integer "integer"
  = sign:"-"? digits:([0-9]+)

decimal "decimal"
  = sign:"-"? float:$(characteristic:[0-9]+ "." decimal:[0-9]+)

number "number"
  = decimal
  / integer

/* characters & strings */

// not " or newline related characters
string "string"
  = str:([^\"\r\n\f]+)

// prefix allows default negation e.g. '-predicate(X,Y)'
predicateIdent "predicate identifier"
  = prefix:$"-"? start:predicateIdentStart chars:predicateIdentChar*

// allow "_" on the start of idents, since heuristic predicates might be present in the output
predicateIdentStart
  = [_a-z]i
  / nonascii

predicateIdentChar
  = [_a-z0-9-]i
  / nonascii

nonascii
  = [\x80-\uFFFF]

E "tab or space"
  = [ \t]

S "whitespace"
  = [ \t\r\n\f]
