{
-- This file is processed by Happy (https://www.haskell.org/happy/) and generates
-- the module `Wasp.Analyzer.Parser.Parser`

module Wasp.Analyzer.Parser.Parser
  ( parse
  ) where

import Wasp.Analyzer.Parser.Lexer
import Wasp.Analyzer.Parser.AST
import Wasp.Analyzer.Parser.Token
import Wasp.Analyzer.Parser.ParseError
import Wasp.Analyzer.Parser.Monad (Parser, initialState, ParserState (..))
import Control.Monad.State.Lazy (get)
import Control.Monad.Except (throwError)
}

-- Lines below tell Happy:
--  - to name the main parsing function `parse` when generating it
--  - that input to parser is `Token` type
--  - to call`parseError` when the parser encounters an error
%name parse
%tokentype { Token }
%error { parseError }

-- This sets up Happy to use a monadic parser and threaded lexer.
-- This means that parser generated by Happy will request tokens from lexer as it needs them instead of
-- requiring a list of all tokens up front.
-- Both lexer and parser operate in the 'Parser' monad, which can be used to track shared state and errors.
-- Check https://www.haskell.org/happy/doc/html/sec-monads.html#sec-lexers for more details.
%monad { Parser }
%lexer { lexer } { Token { tokenType = TEOF } }

-- This section defines the names that are used in the grammar section to
-- refer to each type of token.


%token
  import { Token { tokenType = TImport } }
  from   { Token { tokenType = TFrom } }
  string { Token { tokenType = TString $$ } }
  int    { Token { tokenType = TInt $$ } }
  double { Token { tokenType = TDouble $$ } }
  true   { Token { tokenType = TTrue } }
  false  { Token { tokenType = TFalse } }
  '{='   { Token { tokenType = TLQuote $$ } }
  quoted { Token { tokenType = TQuoted $$ } }
  '=}'   { Token { tokenType =  TRQuote $$ } }
  ident  { Token { tokenType = TIdentifier $$ } }
  '{'    { Token { tokenType = TLCurly } }
  '}'    { Token { tokenType = TRCurly } }
  ','    { Token { tokenType = TComma } }
  ':'    { Token { tokenType = TColon } }
  '['    { Token { tokenType = TLSquare } }
  ']'    { Token { tokenType = TRSquare } }

%%
-- Grammar rules

Wasp :: { AST }
  : Stmt { AST [$1] }
  | Wasp Stmt { AST $ astStmts $1 ++ [$2] }

Stmt :: { Stmt }
  : Decl { $1 }
Decl :: { Stmt }
  : ident ident Expr { Decl $1 $2 $3 }

Expr :: { Expr }
  : Dict { $1 }
  | List { $1 }
  | Extimport { $1 }
  | Quoter { $1 }
  | string { StringLiteral $1 }
  | int { IntegerLiteral $1 }
  | double { DoubleLiteral $1 }
  | true { BoolLiteral True }
  | false { BoolLiteral False }
  | ident { Var $1 }

Dict :: { Expr }
  : '{' DictEntries '}' { Dict $2 }
  | '{' DictEntries ',' '}' { Dict $2 }
  | '{' '}' { Dict [] }
DictEntries :: { [(Identifier, Expr)] }
  : DictEntry { [$1] }
  | DictEntries ',' DictEntry { $1 ++ [$3] }
DictEntry :: { (Identifier, Expr) }
  : ident ':' Expr { ($1, $3) }

List :: { Expr }
  : '[' ListVals ']' { List $2 }
  | '[' ListVals ',' ']' { List $2 }
  |  '[' ']' { List [] }
ListVals :: { [Expr] }
  : Expr { [$1] }
  | ListVals ',' Expr { $1 ++ [$3] }

Extimport :: { Expr }
  : import Name from string { ExtImport $2 $4 }
Name :: { ExtImportName }
  : ident { ExtImportModule $1 }
  | '{' ident '}' { ExtImportField $2 }

Quoter :: { Expr }
  : SourcePosition '{=' Quoted SourcePosition '=}' {% if $2 /= $5
                                                       then throwError $ QuoterDifferentTags ($2, $1) ($5, $4)
                                                       else return $ Quoter $2 $3
                                                   }
Quoted :: { String }
  : quoted { $1 }
  | Quoted quoted { $1 ++ $2 }

SourcePosition :: { SourcePosition }
  : {- empty -} {% fmap parserSourcePosition get }

{
parseError :: Token -> Parser a
parseError token = throwError $ ParseError token
}
