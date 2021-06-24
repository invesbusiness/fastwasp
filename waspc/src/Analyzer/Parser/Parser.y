{
module Analyzer.Parser.Parser
  ( parse
  ) where

import Analyzer.Parser.Lexer
import Analyzer.Parser.Syntax
import Analyzer.Parser.Util (Parser, initialState, ParseState (..))
import Control.Monad.Trans.State.Lazy (evalStateT, get)
import Control.Monad.Trans.Except (throwE, runExcept)
import Control.Monad.Trans.Class (lift)
}

%name parse
%tokentype { Token }
%error { parseError }

%monad { Parser }
%lexer { lexer } { Token { tokenClass = TEOF } }

%token
  import { Token { tokenClass = TImport } }
  from { Token { tokenClass = TFrom } }
  string { Token { tokenClass = TString $$ } }
  int { Token { tokenClass = TInt $$ } }
  double { Token { tokenClass = TDouble $$ } }
  true { Token { tokenClass = TTrue } }
  false { Token { tokenClass = TFalse } }
  quoter {Token { tokenClass =  TQuoter $$ } }
  ident { Token { tokenClass = TIdent $$ } }
  '{' { Token { tokenClass = TLCurly } }
  '}' { Token { tokenClass = TRCurly } }
  ',' { Token { tokenClass = TComma } }
  ':' { Token { tokenClass = TColon } }
  '[' { Token { tokenClass = TLSquare } }
  ']' { Token { tokenClass = TRSquare } }

%%

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
  | quoter { let (open, body, close) = $1 in Quoter open body close }
  | string { StringLiteral $1 }
  | int { IntegerLiteral $1 }
  | double { DoubleLiteral $1 }
  | true { BoolLiteral True }
  | false { BoolLiteral False }
  | ident { Identifier $1 }

Dict :: { Expr }
  : '{' DictEntries '}' { Dict $2 }
  | '{' DictEntries ',' '}' { Dict $2 }
  | '{' '}' { Dict [] }
DictEntries :: { [(Ident, Expr)] }
  : DictEntry { [$1] }
  | DictEntries ',' DictEntry { $1 ++ [$3] }
DictEntry :: { (Ident, Expr) }
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

{
parseError :: Token -> Parser a
parseError token = lift $ throwE $ ParseError token
}
