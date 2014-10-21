use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011;
use MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011::Actions;
use Carp qw/croak/;

# ABSTRACT: ISO ANSI C 2011 grammar written in Marpa BNF

our $VERSION = '0.27'; # TRIAL VERSION


our %DEFAULT_PAUSE = (
    TYPEDEF_NAME         => 'before',
    ENUMERATION_CONSTANT => 'before',
    IDENTIFIER           => 'before',
    # MSVS_ASM             => 'before',
    SEMICOLON            => 'after',
    LCURLY_SCOPE         => 'after',
    RCURLY_SCOPE         => 'after',
    COMMA                => 'after',
    EQUAL                => 'after',
    LPAREN_SCOPE         => 'after',
    RPAREN_SCOPE         => 'after',
);

sub new {
  my ($class, $pausep) = @_;

  my $self  = {
    _grammar_option => {action_object  => sprintf('%s::%s', __PACKAGE__, 'Actions')},
    _recce_option => {ranking_method => 'high_rule_only'},
  };
  #
  # Rework the grammar to have the pauses:
  # Those in %DEFAULT_PAUSE cannot be altered.
  # The other lexemes given in argument will get a pause => after eventually
  #
  my %pause = ();
  if (defined($pausep)) {
      if (ref($pausep) ne 'HASH') {
	  croak 'pausep must be a reference to HASH';
      }
      map {$pause{$_} = 'after'} keys %{$pausep};
  }
  map {$pause{$_} = $DEFAULT_PAUSE{$_}} keys %DEFAULT_PAUSE;

  $self->{_content} = '';
  my $allb = exists($pause{__ALL__});
  while (defined($_ = <DATA>)) {
      my $line = $_;
      if ($line =~ /^\s*:lexeme\s*~\s*<(\w+)>/) {
	  my $lexeme = substr($line, $-[1], $+[1] - $-[1]);
          #
          # Doing this test first will make sure DEFAULT_PAUSE lexemes
          # will always get the correct 'pause' value (i.e. after or before)
          #
	  if (exists($pause{$lexeme})) {
            if (! ($line =~ /\bpause\b/)) {
	      substr($line, -1, 1) = " pause => $pause{$lexeme}\n";
            }
	  } elsif ($allb) {
            if (! ($line =~ /\bpause\b/)) {
              #
              # Hardcoded to 'after'
              #
	      substr($line, -1, 1) = " pause => after\n";
            }
          }
      }
      $self->{_content} .= $line;
  }

  bless($self, $class);

  return $self;
}


sub content {
    my ($self) = @_;
    return $self->{_content};
}


sub grammar_option {
    my ($self) = @_;
    return $self->{_grammar_option};
}


sub recce_option {
    my ($self) = @_;
    return $self->{_recce_option};
}

1;

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011 - ISO ANSI C 2011 grammar written in Marpa BNF

=head1 VERSION

version 0.27

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011;

    my $grammar = MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011->new();

    my $grammar_content = $grammar->content();
    my $grammar_option = $grammar->grammar_option();
    my $recce_option = $grammar->recce_option();

=head1 DESCRIPTION

This modules returns describes the ISO ANSI C 2011 C grammar written in Marpa BNF, as of L<http://www.quut.com/c/ANSI-C-grammar-y-2011.html> and L<http://www.quut.com/c/ANSI-C-grammar-l.html>.

=head1 SUBROUTINES/METHODS

=head2 new([$pausep])

Instance a new object. Takes a reference to a HASH for lexemes for which a pause after is requested.

=head2 content()

Returns the content of the grammar. Takes no argument.

=head2 grammar_option()

Returns recommended option for Marpa::R2::Scanless::G->new(), returned as a reference to a hash.

=head2 recce_option()

Returns recommended option for Marpa::R2::Scanless::R->new(), returned as a reference to a hash.

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__DATA__
################################################################################################################
#                                                    grammar
#
# 2011 ISO C, as of http://www.quut.com/c/ANSI-C-grammar-l.html
#                   http://www.quut.com/c/ANSI-C-grammar-y-2011.html
#
################################################################################################################

#
# Defaults
#
:default ::= action => [values] bless => ::lhs
lexeme default = action => [start,length,value]

#
# G1 (grammar), c.f. http://www.quut.com/c/ANSI-C-grammar-y-2011.html
#
:start ::= translationUnit

primaryExpression
	::= IDENTIFIER
	| constant
	| string
	| LPAREN expression RPAREN
	| genericSelection
        | gccStatementExpression


constant
	::= I_CONSTANT         # includes character_constant
	| F_CONSTANT
	| ENUMERATION_CONSTANT # after it has been defined as such

event 'enumerationConstantIdentifier$' = completed <enumerationConstantIdentifier>
enumerationConstantIdentifier  # before it has been defined as such
	::= IDENTIFIER_UNAMBIGUOUS

enumerationConstant            # before it has been defined as such
	::= enumerationConstantIdentifier

stringLiteral ::= STRING_LITERAL_UNIT+

string
	::= stringLiteral
	| FUNC_NAME

genericSelection
	::= GENERIC LPAREN assignmentExpression COMMA genericAssocList RPAREN

genericAssocList
	::= genericAssociation
	| genericAssocList COMMA genericAssociation

genericAssociation
	::= typeName COLON assignmentExpression
	| DEFAULT COLON assignmentExpression

postfixExpression
	::= primaryExpression
	| postfixExpression LBRACKET expression RBRACKET
	| postfixExpression LPAREN RPAREN
	| postfixExpression LPAREN argumentExpressionList RPAREN
        | gccBuiltinVaStart
        | gccBuiltinVaEnd
        | gccBuiltinVaArg
        | gccBuiltinOffsetof
	| postfixExpression DOT IDENTIFIER_UNAMBIGUOUS
	| postfixExpression PTR_OP IDENTIFIER_UNAMBIGUOUS
	| postfixExpression INC_OP
	| postfixExpression DEC_OP
	| LPAREN typeName RPAREN LCURLY initializerList RCURLY
	| LPAREN typeName RPAREN LCURLY initializerList COMMA RCURLY

argumentExpressionList
	::= assignmentExpression
	| argumentExpressionList COMMA assignmentExpression
	| argumentExpressionList COMMA

gccAlignofExpression ::= GCC_ALIGNOF unaryExpression
                       | GCC_ALIGNOF LPAREN typeName RPAREN

unaryExpression
	::= postfixExpression
	| (gccExtension) postfixExpression
	| INC_OP unaryExpression
	| DEC_OP unaryExpression
	| unaryOperator castExpression
	| SIZEOF unaryExpression
	| SIZEOF LPAREN typeName RPAREN
	| ALIGNOF LPAREN typeName RPAREN
        | gccAlignofExpression

unaryOperator
	::= AMPERSAND
	| STAR
	| PLUS
	| HYPHEN
	| TILDE
	| EXCLAMATION

castExpression
	::= unaryExpression
	| LPAREN typeName RPAREN castExpression

multiplicativeExpression
	::= castExpression
	| multiplicativeExpression STAR castExpression
	| multiplicativeExpression SLASH castExpression
	| multiplicativeExpression PERCENT castExpression

additiveExpression
	::= multiplicativeExpression
	| additiveExpression PLUS multiplicativeExpression
	| additiveExpression HYPHEN multiplicativeExpression

shiftExpression
	::= additiveExpression
	| shiftExpression LEFT_OP additiveExpression
	| shiftExpression RIGHT_OP additiveExpression

relationalExpression
	::= shiftExpression
	| relationalExpression LESS_THAN shiftExpression
	| relationalExpression GREATER_THAN shiftExpression
	| relationalExpression LE_OP shiftExpression
	| relationalExpression GE_OP shiftExpression

equalityExpression
	::= relationalExpression
	| equalityExpression EQ_OP relationalExpression
	| equalityExpression NE_OP relationalExpression

andExpression
	::= equalityExpression
	| andExpression AMPERSAND equalityExpression

exclusiveOrExpression
	::= andExpression
	| exclusiveOrExpression CARET andExpression

inclusiveOrExpression
	::= exclusiveOrExpression
	| inclusiveOrExpression VERTICAL_BAR exclusiveOrExpression

logicalAndExpression
	::= inclusiveOrExpression
	| logicalAndExpression AND_OP inclusiveOrExpression

logicalOrExpression
	::= logicalAndExpression
	| logicalOrExpression OR_OP logicalAndExpression

#
# Following yafce: in C grammar they put conditionalExpression, but in fact it must be
# assignmentExpression, otherwise pnp ? x : x = 0x388;
# C.f. http://padator.org/software/project-yacfe/
#
conditionalExpression
	::= logicalOrExpression
	| logicalOrExpression QUESTION_MARK expression COLON assignmentExpression
	| logicalOrExpression QUESTION_MARK COLON assignmentExpression          # GCC Extension

#
# Following yafce: in C grammar they put unaryExpression, but in fact it must be
# castExpression, otherwise (int * ) xxx = &yy; is not allowed
# C.f. http://padator.org/software/project-yacfe/
#
assignmentExpression
	::= conditionalExpression
	| castExpression assignmentOperator assignmentExpression

assignmentOperator
	::= EQUAL
	| MUL_ASSIGN
	| DIV_ASSIGN
	| MOD_ASSIGN
	| ADD_ASSIGN
	| SUB_ASSIGN
	| LEFT_ASSIGN
	| RIGHT_ASSIGN
	| AND_ASSIGN
	| XOR_ASSIGN
	| OR_ASSIGN

expression
	::= assignmentExpression
	| expression COMMA assignmentExpression

constantExpression
	::= conditionalExpression # with constraints

# ###############################################################################################
# A directDeclarator introduces a typedefName only when it eventually participates in the grammar
# rule:
# declaration ::= declarationSpecifiers initDeclaratorList SEMICOLON
# ###############################################################################################
event 'declarationCheckdeclarationSpecifiers$' = completed <declarationCheckdeclarationSpecifiers>
declarationCheckdeclarationSpecifiers ::= declarationSpecifiers

event 'declarationCheckinitDeclaratorList$' = completed <declarationCheckinitDeclaratorList>
declarationCheckinitDeclaratorList    ::= initDeclaratorList

event 'declarationCheck$' = completed <declarationCheck>
declarationCheck ::= declarationCheckdeclarationSpecifiers declarationCheckinitDeclaratorList SEMICOLON

declaration
	::= declarationSpecifiers SEMICOLON
	| declarationCheck
	| staticAssertDeclaration

gccExtension ::= GCC_EXTENSION

#declarationSpecifiersUnit ::= storageClassSpecifier
#                            | typeSpecifier
#                            | typeQualifier
#                            | functionSpecifier
#                            | alignmentSpecifier
#                            | (gccExtension)

declarationSpecifiers ::= declarationSpecifiers0
                        | declarationSpecifiers1
                        | declarationSpecifiers2

declarationSpecifiers0 ::=       # List without type specifiers
                           storageClassSpecifier
                         | declarationSpecifiers0 storageClassSpecifier
                         | typeQualifier
                         | declarationSpecifiers0 typeQualifier
                         | functionSpecifier
                         | declarationSpecifiers0 functionSpecifier
                         | alignmentSpecifier
                         | declarationSpecifiers0 alignmentSpecifier
                         | (gccExtension)
                         | declarationSpecifiers0 (gccExtension)

declarationSpecifiers1 ::=       # List with a single typeSpecifier1
                           typeSpecifier1
                         | declarationSpecifiers0 typeSpecifier1
                         | declarationSpecifiers1 storageClassSpecifier
                         | declarationSpecifiers1 typeQualifier
                         | declarationSpecifiers1 functionSpecifier
                         | declarationSpecifiers1 alignmentSpecifier
                         | declarationSpecifiers1 (gccExtension)

declarationSpecifiers2 ::=       # List with one or more typeSpecifier2
                           typeSpecifier2
                         | declarationSpecifiers0 typeSpecifier2
                         | declarationSpecifiers2 typeSpecifier2
                         | declarationSpecifiers2 storageClassSpecifier
                         | declarationSpecifiers2 typeQualifier
                         | declarationSpecifiers2 functionSpecifier
                         | declarationSpecifiers2 alignmentSpecifier
                         | declarationSpecifiers2 (gccExtension)

# declarationSpecifiers ::= declarationSpecifiersUnit+

initDeclaratorList
	::= initDeclarator
	| initDeclaratorList COMMA initDeclarator

initDeclarator
	::= declarator EQUAL initializer
	| declarator

event 'storageClassSpecifierTypedef$' = completed <storageClassSpecifierTypedef>
storageClassSpecifierTypedef
	::= TYPEDEF

storageClassSpecifier
	::= storageClassSpecifierTypedef # identifiers must be flagged as TYPEDEF_NAME
	| EXTERN
	| STATIC
	| THREAD_LOCAL
	| AUTO
	| REGISTER

#
# Following advice at http://eli-project.sourceforge.net/c_html/c.html, typeSpecifier is
# divided into two parts: those than only appear in lists of one element, those that can be
# be used to form lists of one or more elements
#
typeSpecifier1
	::= VOID
	| FLOAT
	| structOrUnionSpecifier
	| enumSpecifier
	| TYPEDEF_NAME		# after it has been defined as such

typeSpecifier2
	::= CHAR
	| SHORT
	| INT
	| LONG
	| DOUBLE
	| SIGNED
	| UNSIGNED
	| BOOL
	| LABEL
	| COMPLEX
	| IMAGINARY	  	# non-mandated extension
	| atomicTypeSpecifier
        | msvsBuiltinType
        | gccBuiltinType

event 'structContextStart[]' = nulled <structContextStart>
structContextStart ::=

event 'structContextEnd[]' = nulled <structContextEnd>
structContextEnd ::=

structOrUnionSpecifier
	::= structOrUnion LCURLY <structContextStart> structDeclarationList RCURLY <structContextEnd>
	| structOrUnion IDENTIFIER_UNAMBIGUOUS LCURLY <structContextStart> structDeclarationList RCURLY <structContextEnd>
	| structOrUnion IDENTIFIER_UNAMBIGUOUS

structOrUnion
	::= STRUCT
	| UNION

structDeclarationList ::= structDeclaration+

structDeclaration
	::= specifierQualifierList SEMICOLON	# for anonymous struct/union
	| specifierQualifierList structDeclaratorList SEMICOLON
	| SEMICOLON                             # GCC extension

#specifierQualifierListUnit ::= typeSpecifier
#                             | typeQualifier
#                             | (gccExtension)

# specifierQualifierList ::= specifierQualifierListUnit+

specifierQualifierList ::= specifierQualifierList0
                         | specifierQualifierList1
                         | specifierQualifierList2

specifierQualifierList0 ::= # List without type specifiers
                            typeQualifier
                          | specifierQualifierList0 typeQualifier
                          | (gccExtension)
                          | specifierQualifierList0 (gccExtension)

specifierQualifierList1 ::= # List with a single typeSpecifier1
                            typeSpecifier1
                          | specifierQualifierList0 typeSpecifier1
                          | specifierQualifierList1 typeQualifier
                          | specifierQualifierList1 (gccExtension)

specifierQualifierList2 ::= # List with one or more typeSpecifier2
                            typeSpecifier2
                          | specifierQualifierList0 typeSpecifier2
                          | specifierQualifierList2 typeSpecifier2
                          | specifierQualifierList2 typeQualifier
                          | specifierQualifierList2 (gccExtension)

structDeclaratorList
	::= structDeclarator
	| structDeclaratorList COMMA structDeclarator

structDeclarator
	::= COLON constantExpression
	| declarator COLON constantExpression
	| declarator

enumSpecifier
	::= ENUM LCURLY enumeratorList RCURLY
	| ENUM LCURLY enumeratorList COMMA RCURLY
	| ENUM IDENTIFIER_UNAMBIGUOUS LCURLY enumeratorList RCURLY
	| ENUM IDENTIFIER_UNAMBIGUOUS LCURLY enumeratorList COMMA RCURLY
	| ENUM IDENTIFIER_UNAMBIGUOUS

enumeratorList
	::= enumerator
	| enumeratorList COMMA enumerator

enumerator	# identifiers must be flagged as ENUMERATION_CONSTANT
	::= enumerationConstant EQUAL constantExpression
	| enumerationConstant

atomicTypeSpecifier
	::= ATOMIC LPAREN typeName RPAREN

typeQualifier
	::= CONST
	| RESTRICT
	| VOLATILE
	| ATOMIC
	| MSVS_W64
	| MSVS_PTR32
	| MSVS_PTR64

functionSpecifier
	::= INLINE
	| NORETURN

alignmentSpecifier
	::= ALIGNAS LPAREN typeName RPAREN
	| ALIGNAS LPAREN constantExpression RPAREN

msvsAttributeAny ::= msvsAttribute*

declarator
	::= pointer msvsAttributeAny directDeclarator
	| pointer msvsAttributeAny directDeclarator gccAsmExpression
	| msvsAttributeAny directDeclarator
	| msvsAttributeAny directDeclarator gccAsmExpression
        #
        # Microsoft hack that does not really declare a declarator
        #
        | MSVS___C_ASSERT__ LBRACKET expression RBRACKET

event 'directDeclaratorIdentifier$' = completed <directDeclaratorIdentifier>
directDeclaratorIdentifier
	::= IDENTIFIER

directDeclarator
	::= directDeclaratorIdentifier
	| LPAREN declarator RPAREN
	| directDeclarator LBRACKET RBRACKET
	| directDeclarator LBRACKET STAR RBRACKET
	| directDeclarator LBRACKET STATIC gccArrayTypeModifierList assignmentExpression RBRACKET
	| directDeclarator LBRACKET STATIC assignmentExpression RBRACKET
	| directDeclarator LBRACKET gccArrayTypeModifierList STAR RBRACKET
	| directDeclarator LBRACKET gccArrayTypeModifierList STATIC assignmentExpression RBRACKET
	| directDeclarator LBRACKET gccArrayTypeModifierList assignmentExpression RBRACKET
	| directDeclarator LBRACKET gccArrayTypeModifierList RBRACKET
	| directDeclarator LBRACKET assignmentExpression RBRACKET
	| directDeclarator LPAREN_SCOPE parameterTypeList RPAREN_SCOPE
	| directDeclarator LPAREN_SCOPE RPAREN_SCOPE
	| directDeclarator LPAREN_SCOPE identifierList RPAREN_SCOPE

pointerQualifier ::= typeQualifier

pointerQualifierList ::= pointerQualifier+

pointer
	::= msvsAttributeAny STAR pointerQualifierList pointer
	| msvsAttributeAny STAR pointerQualifierList
	| msvsAttributeAny STAR pointer
	| msvsAttributeAny STAR

gccArrayTypeModifierList ::= gccArrayTypeModifier+

#typeQualifierList
#	::= typeQualifier
#	| typeQualifierList typeQualifier

parameterTypeList
	::= parameterList COMMA ELLIPSIS
	| parameterList

parameterList
	::= parameterDeclaration
	| parameterList COMMA parameterDeclaration

event 'parameterDeclarationdeclarationSpecifiers$' = completed <parameterDeclarationdeclarationSpecifiers>
parameterDeclarationdeclarationSpecifiers ::= declarationSpecifiers

event 'parameterDeclarationCheck$' = completed <parameterDeclarationCheck>
parameterDeclarationCheck ::= parameterDeclarationdeclarationSpecifiers declarator

parameterDeclaration
	::= parameterDeclarationCheck               rank =>  0
	| declarationSpecifiers abstractDeclarator  rank => -1
	| declarationSpecifiers                     rank => -2

identifierList
	::= IDENTIFIER
	| identifierList COMMA IDENTIFIER

typeName
	::= specifierQualifierList abstractDeclarator
	| specifierQualifierList

abstractDeclarator
	::= pointer msvsAttributeAny directAbstractDeclarator
	| pointer msvsAttributeAny directAbstractDeclarator gccAsmExpression
	| pointer msvsAttributeAny
	| directAbstractDeclarator
	| directAbstractDeclarator gccAsmExpression

directAbstractDeclarator
	::= LPAREN abstractDeclarator RPAREN
	| LBRACKET RBRACKET
	| LBRACKET STAR RBRACKET
	| LBRACKET STATIC gccArrayTypeModifierList assignmentExpression RBRACKET
	| LBRACKET STATIC assignmentExpression RBRACKET
	| LBRACKET gccArrayTypeModifierList STATIC assignmentExpression RBRACKET
	| LBRACKET gccArrayTypeModifierList assignmentExpression RBRACKET
	| LBRACKET gccArrayTypeModifierList RBRACKET
	| LBRACKET assignmentExpression RBRACKET
	| directAbstractDeclarator LBRACKET RBRACKET
	| directAbstractDeclarator LBRACKET STAR RBRACKET
	| directAbstractDeclarator LBRACKET STATIC gccArrayTypeModifierList assignmentExpression RBRACKET
	| directAbstractDeclarator LBRACKET STATIC assignmentExpression RBRACKET
	| directAbstractDeclarator LBRACKET gccArrayTypeModifierList assignmentExpression RBRACKET
	| directAbstractDeclarator LBRACKET gccArrayTypeModifierList STATIC assignmentExpression RBRACKET
	| directAbstractDeclarator LBRACKET gccArrayTypeModifierList RBRACKET
	| directAbstractDeclarator LBRACKET assignmentExpression RBRACKET
	| LPAREN_SCOPE RPAREN_SCOPE
	| LPAREN_SCOPE parameterTypeList RPAREN_SCOPE
	| directAbstractDeclarator LPAREN_SCOPE RPAREN_SCOPE
	| directAbstractDeclarator LPAREN_SCOPE parameterTypeList RPAREN_SCOPE

initializer
	::= LCURLY initializerList RCURLY
	| LCURLY initializerList COMMA RCURLY
	| assignmentExpression

initializerList
	::= designation initializer
	| initializer
	| IDENTIFIER COLON initializer
	| initializerList COMMA designation initializer
	| initializerList COMMA initializer

designation
	::= designatorList EQUAL

designatorList ::= designator+

designator
	::= LBRACKET constantExpression RBRACKET
	| DOT IDENTIFIER_UNAMBIGUOUS
        | LBRACKET constantExpression ELLIPSIS constantExpression RBRACKET # GCC Extension

staticAssertDeclaration
	::= STATIC_ASSERT LPAREN constantExpression COMMA stringLiteral RPAREN SEMICOLON

statement
	::= labeledStatement
	| compoundStatement
	| expressionStatement
	| selectionStatement
	| iterationStatement
	| jumpStatement
        | msvsAsmStatement
        | gccAsmStatement

labeledStatement
	::= IDENTIFIER COLON statement
	| CASE constantExpression COLON statement
	| DEFAULT COLON statement

compoundStatement
	::= LCURLY_SCOPE RCURLY_SCOPE
	| LCURLY_SCOPE blockItemList RCURLY_SCOPE

blockItemList ::= blockItem+

blockItem
	::= declaration
	| statement

expressionStatement
	::= SEMICOLON
	| expression SEMICOLON

selectionStatement
	::= IF LPAREN expression RPAREN statement ELSE statement
	| IF LPAREN expression RPAREN statement rank => 1
	| SWITCH LPAREN expression RPAREN statement

iterationStatement
	::= WHILE LPAREN expression RPAREN statement
	| DO statement WHILE LPAREN expression RPAREN SEMICOLON
	| FOR LPAREN expressionStatement expressionStatement RPAREN statement
	| FOR LPAREN expressionStatement expressionStatement expression RPAREN statement
	| FOR LPAREN declaration expressionStatement RPAREN statement
	| FOR LPAREN declaration expressionStatement expression RPAREN statement

jumpStatement
	::= GOTO IDENTIFIER_UNAMBIGUOUS SEMICOLON
	| CONTINUE SEMICOLON
	| BREAK SEMICOLON
	| RETURN SEMICOLON
	| RETURN expression SEMICOLON

event 'translationUnit$' = completed <translationUnit>
translationUnit ::= externalDeclaration+

event '^externalDeclaration' = predicted <externalDeclaration>
externalDeclaration
	::= functionDefinition
	| declaration

compoundStatementReenterScope ::= LCURLY RCURLY_SCOPE
	                        | LCURLY blockItemList RCURLY_SCOPE

functionDefinition
	::= functionDefinitionCheck1
	| functionDefinitionCheck2

event 'fileScopeDeclarator$' = completed <fileScopeDeclarator>
fileScopeDeclarator ::= declarator

event 'functionDefinitionCheck1$' = completed <functionDefinitionCheck1>
functionDefinitionCheck1 ::= functionDefinitionCheck1declarationSpecifiers fileScopeDeclarator functionDefinitionCheck1declarationList compoundStatementReenterScope

event 'functionDefinitionCheck2$' = completed <functionDefinitionCheck2>
functionDefinitionCheck2 ::= functionDefinitionCheck2declarationSpecifiers fileScopeDeclarator                                         compoundStatementReenterScope

event 'functionDefinitionCheck1declarationSpecifiers$' = completed <functionDefinitionCheck1declarationSpecifiers>
functionDefinitionCheck1declarationSpecifiers ::= declarationSpecifiers

event 'functionDefinitionCheck2declarationSpecifiers$' = completed <functionDefinitionCheck2declarationSpecifiers>
functionDefinitionCheck2declarationSpecifiers ::= declarationSpecifiers

event 'functionDefinitionCheck1declarationList$' = completed <functionDefinitionCheck1declarationList>
functionDefinitionCheck1declarationList ::= declarationList

declarationList ::= declaration+

#
# G0 (tokens), c.f. http://www.quut.com/c/ANSI-C-grammar-l.html
#

# Intermediary tokens

O          ~ [0-7]
O_any      ~ O*
D          ~ [0-9]
D_any      ~ D*
D_many     ~ D+
NZ         ~ [1-9]
L          ~ [a-zA-Z_]
A          ~ [a-zA-Z_0-9]
A_any      ~ A*
H          ~ [a-fA-F0-9]
H_any      ~ H*
H_many     ~ H+
HP         ~ '0' [xX]
B          ~ [0-1]
B_many     ~ B+
BP         ~ '0' [bB]
SIGN_maybe ~ [+-]
SIGN_maybe ~
E          ~ [Ee] SIGN_maybe D_many
E_maybe    ~ E
E_maybe    ~
P          ~ [Pp] SIGN_maybe D_many
FS         ~ [fFlL]
FS_maybe   ~ FS
FS_maybe   ~
LL         ~ 'll' | 'LL' | [lL]
LL_maybe   ~ LL
LL_maybe   ~
U          ~ [uU]
U_maybe    ~ U
U_maybe    ~
IS         ~ U LL_maybe | LL U_maybe
IS_maybe   ~ IS
IS_maybe   ~
CP         ~ [uUL]
CP_maybe   ~ CP
CP_maybe   ~
SP         ~ 'u8' | [uUL]
SP_maybe   ~ SP
SP_maybe   ~
ES_AFTERBS ~ [\'\"\?\\abfnrtv]
           | O
           | O O
           | O O O
           | 'x' H_many
ES         ~ BS ES_AFTERBS
WS         ~ [ \t\v\n\f]
WS_any     ~ WS*
WS_many    ~ WS+

# Lexemes
:lexeme ~ <AUTO>          priority => -1
AUTO          ~ 'auto'
:lexeme ~ <BREAK>         priority => -2
BREAK         ~ 'break'
:lexeme ~ <CASE>          priority => -3
CASE          ~ 'case'
:lexeme ~ <CHAR>          priority => -4
CHAR          ~ 'char'
:lexeme ~ <CONST>         priority => -5
CONST         ~ 'const'
CONST         ~ '__const'
CONST         ~ 'const__'
CONST         ~ '__const__'
:lexeme ~ <CONTINUE>      priority => -6
CONTINUE      ~ 'continue'
:lexeme ~ <DEFAULT>       priority => -7
DEFAULT       ~ 'default'
:lexeme ~ <DO>            priority => -8
DO            ~ 'do'
:lexeme ~ <DOUBLE>        priority => -9
DOUBLE        ~ 'double'
:lexeme ~ <ELSE>          priority => -10
ELSE          ~ 'else'
:lexeme ~ <ENUM>          priority => -11
ENUM          ~ 'enum'
:lexeme ~ <EXTERN>        priority => -12
EXTERN        ~ 'extern'
:lexeme ~ <FLOAT>         priority => -13
FLOAT         ~ 'float'
:lexeme ~ <FOR>           priority => -14
FOR           ~ 'for'
:lexeme ~ <GOTO>          priority => -15
GOTO          ~ 'goto'
:lexeme ~ <IF>            priority => -16
IF            ~ 'if'
:lexeme ~ <INLINE>        priority => -17
INLINE        ~ 'inline'
INLINE        ~ '__inline__'
INLINE        ~ 'inline__'
INLINE        ~ '__inline'
INLINE        ~ '__forceinline'           # MSVS
:lexeme ~ <INT>           priority => -18
INT           ~ 'int'
:lexeme ~ <LONG>          priority => -19
LONG          ~ 'long'
:lexeme ~ <REGISTER>      priority => -20
REGISTER      ~ 'register'
:lexeme ~ <RESTRICT>      priority => -21
RESTRICT      ~ 'restrict'
RESTRICT      ~ '__restrict'
RESTRICT      ~ 'restrict__'
RESTRICT      ~ '__restrict__'              # gcc
:lexeme ~ <RETURN>        priority => -22
RETURN        ~ 'return'
:lexeme ~ <SHORT>         priority => -23
SHORT         ~ 'short'
:lexeme ~ <SIGNED>        priority => -24
SIGNED        ~ 'signed'
SIGNED        ~ '__signed'
SIGNED        ~ '__signed__'
:lexeme ~ <SIZEOF>        priority => -25
SIZEOF        ~ 'sizeof'
:lexeme ~ <STATIC>        priority => -26
STATIC        ~ 'static'
:lexeme ~ <STRUCT>        priority => -27
STRUCT        ~ 'struct'
:lexeme ~ <SWITCH>        priority => -28
SWITCH        ~ 'switch'
:lexeme ~ <TYPEDEF>       priority => -29
TYPEDEF       ~ 'typedef'
:lexeme ~ <UNION>         priority => -30
UNION         ~ 'union'
:lexeme ~ <UNSIGNED>      priority => -31
UNSIGNED      ~ 'unsigned'
UNSIGNED      ~ '__unsigned'
UNSIGNED      ~ '__unsigned__'
:lexeme ~ <VOID>          priority => -32
VOID          ~ 'void'
:lexeme ~ <VOLATILE>      priority => -33
VOLATILE      ~ 'volatile'
VOLATILE      ~ '__volatile'
VOLATILE      ~ 'volatile__'
VOLATILE      ~ '__volatile__'
:lexeme ~ <WHILE>         priority => -34
WHILE         ~ 'while'
:lexeme ~ <ALIGNAS>       priority => -35
ALIGNAS       ~ '_Alignas'
:lexeme ~ <ALIGNOF>       priority => -36
ALIGNOF       ~ '_Alignof'
:lexeme ~ <ATOMIC>        priority => -37
ATOMIC        ~ '_Atomic'
:lexeme ~ <BOOL>          priority => -38
BOOL          ~ '_Bool'
:lexeme ~ <LABEL>          priority => -38
LABEL          ~ '__label__'
:lexeme ~ <COMPLEX>       priority => -39
COMPLEX       ~ '_Complex'
COMPLEX       ~ '__complex'
COMPLEX       ~ '__complex__'
:lexeme ~ <GENERIC>       priority => -40
GENERIC       ~ '_Generic'
:lexeme ~ <IMAGINARY>     priority => -41
IMAGINARY     ~ '_Imaginary'
:lexeme ~ <NORETURN>      priority => -42
NORETURN      ~ '_Noreturn'
:lexeme ~ <STATIC_ASSERT> priority => -43
STATIC_ASSERT ~ '_Static_assert'
:lexeme ~ <THREAD_LOCAL>  priority => -44
THREAD_LOCAL  ~ '_Thread_local'
THREAD_LOCAL  ~ '__thread' # gcc
:lexeme ~ <FUNC_NAME>     priority => -45
FUNC_NAME     ~ '__func__'

#
## DETERMINED AT RUN TIME
#
:lexeme ~ <TYPEDEF_NAME>           priority => -100
:lexeme ~ <ENUMERATION_CONSTANT>   priority => -100
:lexeme ~ <IDENTIFIER>             priority => -100
:lexeme ~ <IDENTIFIER_UNAMBIGUOUS> priority => -100
_IDENTIFIER          ~ L A_any
TYPEDEF_NAME         ~ _IDENTIFIER
ENUMERATION_CONSTANT ~ _IDENTIFIER
IDENTIFIER           ~ _IDENTIFIER
IDENTIFIER_UNAMBIGUOUS ~ _IDENTIFIER

:lexeme ~ <I_CONSTANT>         priority => -101
I_CONSTANT ~ HP H_many IS_maybe
           | BP B_many IS_maybe   # Gcc extension: binary constants
           | NZ D_any IS_maybe
           | '0' O_any IS_maybe
           | CP_maybe QUOTE I_CONSTANT_INSIDE_many QUOTE

:lexeme ~ <F_CONSTANT>         priority => -102
F_CONSTANT ~ D_many E FS_maybe
           | D_any '.' D_many E_maybe FS_maybe
           | D_many '.' E_maybe FS_maybe
           | HP H_many P FS_maybe
           | HP H_any '.' H_many P FS_maybe
           | HP H_many '.' P FS_maybe

:lexeme ~ <STRING_LITERAL_UNIT>    priority => -103
STRING_LITERAL_INSIDE ~ [^"\\\n]
STRING_LITERAL_INSIDE ~ ES
STRING_LITERAL_INSIDE_any ~ STRING_LITERAL_INSIDE*
STRING_LITERAL_UNIT ~ SP_maybe '"' STRING_LITERAL_INSIDE_any '"' WS_any
:lexeme ~ <ELLIPSIS>      priority => -104
ELLIPSIS     ~ '...'
:lexeme ~ <RIGHT_ASSIGN>  priority => -105
RIGHT_ASSIGN ~ '>>='
:lexeme ~ <LEFT_ASSIGN>   priority => -106
LEFT_ASSIGN  ~ '<<='
:lexeme ~ <ADD_ASSIGN>    priority => -107
ADD_ASSIGN   ~ '+='
:lexeme ~ <SUB_ASSIGN>    priority => -108
SUB_ASSIGN   ~ '-='
:lexeme ~ <MUL_ASSIGN>    priority => -109
MUL_ASSIGN   ~ '*='
:lexeme ~ <DIV_ASSIGN>    priority => -110
DIV_ASSIGN   ~ '/='
:lexeme ~ <MOD_ASSIGN>    priority => -111
MOD_ASSIGN   ~ '%='
:lexeme ~ <AND_ASSIGN>    priority => -112
AND_ASSIGN   ~ '&='
:lexeme ~ <XOR_ASSIGN>    priority => -113
XOR_ASSIGN   ~ '^='
:lexeme ~ <OR_ASSIGN>     priority => -114
OR_ASSIGN    ~ '|='
:lexeme ~ <RIGHT_OP>      priority => -115
RIGHT_OP     ~ '>>'
:lexeme ~ <LEFT_OP>       priority => -116
LEFT_OP      ~ '<<'
:lexeme ~ <INC_OP>        priority => -117
INC_OP       ~ '++'
:lexeme ~ <DEC_OP>        priority => -118
DEC_OP       ~ '--'
:lexeme ~ <PTR_OP>        priority => -119
PTR_OP       ~ '->'
:lexeme ~ <AND_OP>        priority => -120
AND_OP       ~ '&&'
:lexeme ~ <OR_OP>         priority => -121
OR_OP        ~ '||'
:lexeme ~ <LE_OP>         priority => -122
LE_OP        ~ '<='
:lexeme ~ <GE_OP>         priority => -123
GE_OP        ~ '>='
:lexeme ~ <EQ_OP>         priority => -124
EQ_OP        ~ '=='
:lexeme ~ <NE_OP>         priority => -125
NE_OP        ~ '!='
:lexeme ~ <SEMICOLON>     priority => -126
SEMICOLON                     ~ ';'
:lexeme ~ <LCURLY>        priority => -127
LCURLY                       ~ '{' | '<%'
:lexeme ~ <LCURLY_SCOPE>        priority => -127
LCURLY_SCOPE                       ~ '{' | '<%'
:lexeme ~ <RCURLY>        priority => -128
RCURLY                       ~ '}' | '%>'
:lexeme ~ <RCURLY_SCOPE>        priority => -128
RCURLY_SCOPE                       ~ '}' | '%>'
:lexeme ~ <COMMA>         priority => -129
COMMA                     ~ ','
:lexeme ~ <COLON>         priority => -130
COLON                      ~ ':'
:lexeme ~ <EQUAL>         priority => -131
EQUAL       ~ '='
:lexeme ~ <LPAREN>        priority => -132
LPAREN                ~ '('
:lexeme ~ <LPAREN_SCOPE>        priority => -132
LPAREN_SCOPE                ~ '('
:lexeme ~ <RPAREN>        priority => -133
RPAREN                      ~ ')'
:lexeme ~ <RPAREN_SCOPE>        priority => -133
RPAREN_SCOPE                      ~ ')'
:lexeme ~ <LBRACKET>      priority => -134
LBRACKET      ~ '[' | '<:'
:lexeme ~ <RBRACKET>      priority => -135
RBRACKET      ~ ']' | ':>'
:lexeme ~ <DOT>           priority => -136
DOT           ~ '.'
:lexeme ~ <AMPERSAND>     priority => -137
AMPERSAND     ~ '&'
:lexeme ~ <EXCLAMATION>   priority => -138
EXCLAMATION ~ '!'
:lexeme ~ <TILDE>         priority => -139
TILDE ~ '~'
:lexeme ~ <HYPHEN>        priority => -140
HYPHEN ~ '-'
:lexeme ~ <PLUS>          priority => -141
PLUS ~ '+'
:lexeme ~ <STAR>          priority => -142
STAR ~ '*'
:lexeme ~ <SLASH>         priority => -143
SLASH ~ '/'
:lexeme ~ <PERCENT>       priority => -144
PERCENT ~ '%'
:lexeme ~ <LESS_THAN>     priority => -145
LESS_THAN ~ '<'
:lexeme ~ <GREATER_THAN>  priority => -146
GREATER_THAN ~ '>'
:lexeme ~ <CARET>         priority => -147
CARET ~ '^'
:lexeme ~ <VERTICAL_BAR>  priority => -148
VERTICAL_BAR ~ '|'
:lexeme ~ <QUESTION_MARK> priority => -149
QUESTION_MARK ~ '?'

############################################################################
# Discard of a C comment, c.f. https://gist.github.com/jeffreykegler/5015057
############################################################################
<C style comment> ~ '/*' <comment interior> '*/'
<comment interior> ~
    <optional non stars>
    <optional star prefixed segments>
    <optional pre final stars>
<optional non stars> ~ [^*]*
<optional star prefixed segments> ~ <star prefixed segment>*
<star prefixed segment> ~ <stars> [^/*] <optional star free text>
<stars> ~ [*]+
<optional star free text> ~ [^*]*
<optional pre final stars> ~ [*]*

##########################
# Discard of a C++ comment
##########################
<Cplusplus style comment> ~ '//' <Cplusplus comment interior>
<Cplusplus comment interior> ~ [^\n]*

##############################################
# Discard of some simple annotation directives
##############################################
<MSVS annotation directive start> ~ '[source_annotation_attribute'
<MSVS annotation directive interior single line> ~ [^\n]*
<MSVS annotation directive> ~ <MSVS annotation directive start> <MSVS annotation directive interior single line>

#
# Internal tokens added
#
QUOTE     ~ [']
I_CONSTANT_INSIDE ~ [^'\\\n]
I_CONSTANT_INSIDE ~ ES
I_CONSTANT_INSIDE_many ~ I_CONSTANT_INSIDE+
BS         ~ '\'
ANYTHING_ELSE   ~ [.]

:discard ~ <Cplusplus style comment>
:discard ~ <C style comment>
:discard ~ <MSVS annotation directive>
:discard ~ WS_many       # whitespace separates tokens
:discard ~ ANYTHING_ELSE # discard bad characters

#
# GCC C LEXEMES
#
:lexeme ~ <GCC_ASM>                  priority => -60
GCC_ASM              ~ 'asm__'
GCC_ASM              ~ '__asm'
GCC_ASM              ~ '__asm__'
GCC_ASM              ~ 'asm'
:lexeme ~ <GCC_EXTENSION>            priority => -60
GCC_EXTENSION        ~ 'extension__'
GCC_EXTENSION        ~ '__extension'
GCC_EXTENSION        ~ '__extension__'
:lexeme ~ <GCC_BUILTIN_VA_START>     priority => -60
GCC_BUILTIN_VA_START ~ '__builtin_va_start'
:lexeme ~ <GCC_BUILTIN_VA_END>       priority => -60
GCC_BUILTIN_VA_END   ~ '__builtin_va_end'
:lexeme ~ <GCC_BUILTIN_VA_ARG>       priority => -60
GCC_BUILTIN_VA_ARG   ~ '__builtin_va_arg'
:lexeme ~ <GCC_TYPEOF>               priority => -60
GCC_TYPEOF           ~ 'typeof'
GCC_TYPEOF           ~ '__typeof'
GCC_TYPEOF           ~ '__typeof__'
:lexeme ~ <GCC_BUILTIN_OFFSETOF>     priority => -60
GCC_BUILTIN_OFFSETOF ~ '__builtin_offsetof'
:lexeme ~ <GCC_BUILTIN_VA_LIST>      priority => -60
GCC_BUILTIN_VA_LIST ~ '__builtin_va_list'
GCC_ALIGNOF ~ '__alignof__'
GCC_ALIGNOF ~ 'alignof__'
GCC_ALIGNOF ~ '__alignof'
GCC_ALIGNOF ~ 'alignof'

#
# MSVS C LEXEMES
#
:lexeme ~ <MSVS_ASM>                 priority => -60
MSVS_ASM ~ '__asm'
:lexeme ~ <MSVS_FASTCALL>            priority => -60
MSVS_FASTCALL ~ '__fastcall'
:lexeme ~ <MSVS_THISCALL>            priority => -60
MSVS_THISCALL ~ '__thiscall'
:lexeme ~ <MSVS_BASED>               priority => -60
MSVS_BASED ~ '__based'
:lexeme ~ <MSVS_CDECL>               priority => -60
MSVS_CDECL ~ '__cdecl'
:lexeme ~ <MSVS_CLRCALL>             priority => -60
MSVS_CLRCALL ~ '__clrcall'
:lexeme ~ <MSVS___C_ASSERT__>        priority => -60
MSVS___C_ASSERT__ ~ '__C_ASSERT__'
:lexeme ~ <MSVS_STDCALL>             priority => -60
MSVS_STDCALL ~ '__stdcall'
:lexeme ~ <MSVS_INT8>                priority => -60
MSVS_INT8 ~ '__int8'
:lexeme ~ <MSVS_INT16>               priority => -60
MSVS_INT16 ~ '__int16'
:lexeme ~ <MSVS_INT32>               priority => -60
MSVS_INT32 ~ '__int32'
:lexeme ~ <MSVS_INT64>               priority => -60
MSVS_INT64 ~ '__int64'
:lexeme ~ <MSVS_AT>                  priority => -60
MSVS_AT ~ '@'
:lexeme ~ <MSVS_W64>                 priority => -60
MSVS_W64 ~ '__w64'
:lexeme ~ <MSVS_PTR32>               priority => -60
MSVS_PTR32 ~ '__ptr32'
:lexeme ~ <MSVS_PTR64>               priority => -60
MSVS_PTR64 ~ '__ptr64'

#
# MSVS ASM LEXEMES
# ----------------
:lexeme ~ <MSVS_ASM_REP>                 priority => -60
MSVS_ASM_REP ~ 'REP'
MSVS_ASM_REP ~ 'rep'
:lexeme ~ <MSVS_ASM_REPE>                priority => -60
MSVS_ASM_REPE ~ 'REPE'
MSVS_ASM_REPE ~ 'repe'
:lexeme ~ <MSVS_ASM_REPZ>                priority => -60
MSVS_ASM_REPZ ~ 'REPZ'
MSVS_ASM_REPZ ~ 'repz'
:lexeme ~ <MSVS_ASM_REPNE>               priority => -60
MSVS_ASM_REPNE ~ 'REPNE'
MSVS_ASM_REPNE ~ 'repne'
:lexeme ~ <MSVS_ASM_REPNZ>               priority => -60
MSVS_ASM_REPNZ ~ 'REPNZ'
MSVS_ASM_REPNZ ~ 'repnz'
:lexeme ~ <MSVS_ASM_AND>                 priority => -60
MSVS_ASM_AND ~ 'AND'
MSVS_ASM_AND ~ 'and'
:lexeme ~ <MSVS_ASM_MOD>                 priority => -60
MSVS_ASM_MOD ~ 'MOD'
MSVS_ASM_MOD ~ 'mod'
:lexeme ~ <MSVS_ASM_NOT>                 priority => -60
MSVS_ASM_NOT ~ 'NOT'
MSVS_ASM_NOT ~ 'not'
:lexeme ~ <MSVS_ASM_OR>                  priority => -60
MSVS_ASM_OR ~ 'OR'
MSVS_ASM_OR ~ 'or'
:lexeme ~ <MSVS_ASM_SEG>                 priority => -60
MSVS_ASM_SEG ~ 'SEG'
MSVS_ASM_SEG ~ 'seg'
:lexeme ~ <MSVS_ASM_SHL>                 priority => -60
MSVS_ASM_SHL ~ 'SHL'
MSVS_ASM_SHL ~ 'shl'
:lexeme ~ <MSVS_ASM_SHLD>                priority => -60
MSVS_ASM_SHLD ~ 'SHLD'
MSVS_ASM_SHLD ~ 'shld'
:lexeme ~ <MSVS_ASM_MOV>                 priority => -60
MSVS_ASM_MOV ~ 'MOV'
MSVS_ASM_MOV ~ 'mov'
:lexeme ~ <MSVS_ASM_SHR>                 priority => -60
MSVS_ASM_SHR ~ 'SHR'
MSVS_ASM_SHR ~ 'shr'
:lexeme ~ <MSVS_ASM_XOR>                 priority => -60
MSVS_ASM_XOR ~ 'XOR'
MSVS_ASM_XOR ~ 'xor'
#:lexeme ~ <MSVS_ASM_SHORT>               priority => -60
#MSVS_ASM_SHORT ~ 'SHORT'
:lexeme ~ <MSVS_ASM_TYPE>                priority => -60
MSVS_ASM_TYPE ~ 'TYPE'
MSVS_ASM_TYPE ~ 'type'
#:lexeme ~ <MSVS_ASM_OPATTR>              priority => -60
#MSVS_ASM_OPATTR ~ 'OPATTR'
:lexeme ~ <MSVS_ASM_STAR>                priority => -60
MSVS_ASM_STAR ~ '*'
:lexeme ~ <MSVS_ASM_SLASH>               priority => -60
MSVS_ASM_SLASH ~ '/'
:lexeme ~ <MSVS_ASM_AH>                  priority => -60
MSVS_ASM_AH ~ 'AH'
MSVS_ASM_AH ~ 'ah'
:lexeme ~ <MSVS_ASM_AL>                  priority => -60
MSVS_ASM_AL ~ 'AL'
MSVS_ASM_AL ~ 'al'
:lexeme ~ <MSVS_ASM_AX>                  priority => -60
MSVS_ASM_AX ~ 'AX'
MSVS_ASM_AX ~ 'ax'
:lexeme ~ <MSVS_ASM_BH>                  priority => -60
MSVS_ASM_BH ~ 'BH'
MSVS_ASM_BH ~ 'bh'
:lexeme ~ <MSVS_ASM_BL>                  priority => -60
MSVS_ASM_BL ~ 'BL'
MSVS_ASM_BL ~ 'bl'
:lexeme ~ <MSVS_ASM_BP>                  priority => -60
MSVS_ASM_BP ~ 'BP'
MSVS_ASM_BP ~ 'bp'
:lexeme ~ <MSVS_ASM_BX>                  priority => -60
MSVS_ASM_BX ~ 'BX'
MSVS_ASM_BX ~ 'bx'
:lexeme ~ <MSVS_ASM_BYTE>                priority => -60
MSVS_ASM_BYTE ~ 'BYTE'
MSVS_ASM_BYTE ~ 'byte'
:lexeme ~ <MSVS_ASM_CH>                  priority => -60
MSVS_ASM_CH ~ 'CH'
MSVS_ASM_CH ~ 'ch'
:lexeme ~ <MSVS_ASM_CL>                  priority => -60
MSVS_ASM_CL ~ 'CL'
MSVS_ASM_CL ~ 'cl'
:lexeme ~ <MSVS_ASM_COLON>               priority => -60
MSVS_ASM_COLON ~ ':'
:lexeme ~ <MSVS_ASM_CR0>                 priority => -60
MSVS_ASM_CR0 ~ 'CR0'
MSVS_ASM_CR0 ~ 'cr0'
:lexeme ~ <MSVS_ASM_CR2>                 priority => -60
MSVS_ASM_CR2 ~ 'CR2'
MSVS_ASM_CR2 ~ 'cr2'
:lexeme ~ <MSVS_ASM_CR3>                 priority => -60
MSVS_ASM_CR3 ~ 'CR3'
MSVS_ASM_CR3 ~ 'cr3'
:lexeme ~ <MSVS_ASM_CS>                  priority => -60
MSVS_ASM_CS ~ 'CS'
MSVS_ASM_CS ~ 'cs'
:lexeme ~ <MSVS_ASM_CX>                  priority => -60
MSVS_ASM_CX ~ 'CX'
MSVS_ASM_CX ~ 'cx'
:lexeme ~ <MSVS_ASM_DH>                  priority => -60
MSVS_ASM_DH ~ 'DH'
MSVS_ASM_DH ~ 'dh'
:lexeme ~ <MSVS_ASM_DI>                  priority => -60
MSVS_ASM_DI ~ 'DI'
MSVS_ASM_DI ~ 'di'
:lexeme ~ <MSVS_ASM_DL>                  priority => -60
MSVS_ASM_DL ~ 'DL'
MSVS_ASM_DL ~ 'dl'
:lexeme ~ <MSVS_ASM_DOLLAR>              priority => -60
MSVS_ASM_DOLLAR ~ '$'
:lexeme ~ <MSVS_ASM_DOT>                 priority => -60
MSVS_ASM_DOT ~ '.'
:lexeme ~ <MSVS_ASM_DR0>                 priority => -60
MSVS_ASM_DR0 ~ 'DR0'
MSVS_ASM_DR0 ~ 'dr0'
:lexeme ~ <MSVS_ASM_DR1>                 priority => -60
MSVS_ASM_DR1 ~ 'DR1'
MSVS_ASM_DR1 ~ 'dr1'
:lexeme ~ <MSVS_ASM_DR2>                 priority => -60
MSVS_ASM_DR2 ~ 'DR2'
MSVS_ASM_DR2 ~ 'dr2'
:lexeme ~ <MSVS_ASM_DR3>                 priority => -60
MSVS_ASM_DR3 ~ 'DR3'
MSVS_ASM_DR3 ~ 'dr3'
:lexeme ~ <MSVS_ASM_DR6>                 priority => -60
MSVS_ASM_DR6 ~ 'DR6'
MSVS_ASM_DR6 ~ 'dr6'
:lexeme ~ <MSVS_ASM_DR7>                 priority => -60
MSVS_ASM_DR7 ~ 'DR7'
MSVS_ASM_DR7 ~ 'dr7'
:lexeme ~ <MSVS_ASM_DS>                  priority => -60
MSVS_ASM_DS ~ 'DS'
MSVS_ASM_DS ~ 'ds'
:lexeme ~ <MSVS_ASM_DWORD>               priority => -60
MSVS_ASM_DWORD ~ 'DWORD'
MSVS_ASM_DWORD ~ 'dword'
:lexeme ~ <MSVS_ASM_DX>                  priority => -60
MSVS_ASM_DX ~ 'DX'
MSVS_ASM_DX ~ 'dx'
:lexeme ~ <MSVS_ASM_EAX>                 priority => -60
MSVS_ASM_EAX ~ 'EAX'
MSVS_ASM_EAX ~ 'eax'
:lexeme ~ <MSVS_ASM_EBP>                 priority => -60
MSVS_ASM_EBP ~ 'EBP'
MSVS_ASM_EBP ~ 'ebp'
:lexeme ~ <MSVS_ASM_EBX>                 priority => -60
MSVS_ASM_EBX ~ 'EBX'
MSVS_ASM_EBX ~ 'ebx'
:lexeme ~ <MSVS_ASM_ECX>                 priority => -60
MSVS_ASM_ECX ~ 'ECX'
MSVS_ASM_ECX ~ 'ecx'
:lexeme ~ <MSVS_ASM_EDI>                 priority => -60
MSVS_ASM_EDI ~ 'EDI'
MSVS_ASM_EDI ~ 'edi'
:lexeme ~ <MSVS_ASM_EDX>                 priority => -60
MSVS_ASM_EDX ~ 'EDX'
MSVS_ASM_EDX ~ 'edx'
:lexeme ~ <MSVS_ASM_EQ>                  priority => -60
MSVS_ASM_EQ ~ 'EQ'
MSVS_ASM_EQ ~ 'eq'
:lexeme ~ <MSVS_ASM_ES>                  priority => -60
MSVS_ASM_ES ~ 'ES'
MSVS_ASM_ES ~ 'es'
:lexeme ~ <MSVS_ASM_ESI>                 priority => -60
MSVS_ASM_ESI ~ 'ESI'
MSVS_ASM_ESI ~ 'esi'
:lexeme ~ <MSVS_ASM_ESP>                 priority => -60
MSVS_ASM_ESP ~ 'ESP'
MSVS_ASM_ESP ~ 'esp'
:lexeme ~ <MSVS_ASM_FAR>                 priority => -60
MSVS_ASM_FAR ~ 'FAR'
MSVS_ASM_FAR ~ 'far'
:lexeme ~ <MSVS_ASM_FAR16>               priority => -60
MSVS_ASM_FAR16 ~ 'FAR16'
MSVS_ASM_FAR16 ~ 'far16'
:lexeme ~ <MSVS_ASM_FAR32>               priority => -60
MSVS_ASM_FAR32 ~ 'FAR32'
MSVS_ASM_FAR32 ~ 'far32'
:lexeme ~ <MSVS_ASM_FS>                  priority => -60
MSVS_ASM_FS ~ 'FS'
MSVS_ASM_FS ~ 'fs'
:lexeme ~ <MSVS_ASM_FWORD>               priority => -60
MSVS_ASM_FWORD ~ 'FWORD'
MSVS_ASM_FWORD ~ 'fword'
:lexeme ~ <MSVS_ASM_GE>                  priority => -60
MSVS_ASM_GE ~ 'GE'
MSVS_ASM_GE ~ 'ge'
:lexeme ~ <MSVS_ASM_GS>                  priority => -60
MSVS_ASM_GS ~ 'GS'
MSVS_ASM_GS ~ 'gs'
:lexeme ~ <MSVS_ASM_GT>                  priority => -60
MSVS_ASM_GT ~ 'GT'
MSVS_ASM_GT ~ 'gt'
:lexeme ~ <MSVS_ASM_HIGH>                priority => -60
MSVS_ASM_HIGH ~ 'HIGH'
MSVS_ASM_HIGH ~ 'high'
:lexeme ~ <MSVS_ASM_HIGHWORD>            priority => -60
MSVS_ASM_HIGHWORD ~ 'HIGHWORD'
MSVS_ASM_HIGHWORD ~ 'highword'
:lexeme ~ <MSVS_ASM_LBRACKET>            priority => -60
MSVS_ASM_LBRACKET ~ '['
:lexeme ~ <MSVS_ASM_RBRACKET>            priority => -60
MSVS_ASM_RBRACKET ~ ']'
:lexeme ~ <MSVS_ASM_LE>                  priority => -60
MSVS_ASM_LE ~ 'LE'
MSVS_ASM_LE ~ 'le'
:lexeme ~ <MSVS_ASM_LOCK>                priority => -60
MSVS_ASM_LOCK ~ 'LOCK'
MSVS_ASM_LOCK ~ 'lock'
:lexeme ~ <MSVS_ASM_LOW>                 priority => -60
MSVS_ASM_LOW ~ 'LOW'
MSVS_ASM_LOW ~ 'low'
:lexeme ~ <MSVS_ASM_LOWWORD>             priority => -60
MSVS_ASM_LOWWORD ~ 'LOWWORD'
MSVS_ASM_LOWWORD ~ 'lowword'
:lexeme ~ <MSVS_ASM_LROFFSET>            priority => -60
MSVS_ASM_LROFFSET ~ 'LROFFSET'
MSVS_ASM_LROFFSET ~ 'lroffset'
:lexeme ~ <MSVS_ASM_LT>                  priority => -60
MSVS_ASM_LT ~ 'LT'
MSVS_ASM_LT ~ 'lt'
:lexeme ~ <MSVS_ASM_MINUS>               priority => -60
MSVS_ASM_MINUS ~ '-'
:lexeme ~ <MSVS_ASM_NE>                  priority => -60
MSVS_ASM_NE ~ 'NE'
MSVS_ASM_NE ~ 'ne'
:lexeme ~ <MSVS_ASM_NEAR>                priority => -60
MSVS_ASM_NEAR ~ 'NEAR'
MSVS_ASM_NEAR ~ 'near'
:lexeme ~ <MSVS_ASM_NEAR16>              priority => -60
MSVS_ASM_NEAR16 ~ 'NEAR16'
MSVS_ASM_NEAR16 ~ 'near16'
:lexeme ~ <MSVS_ASM_NEAR32>              priority => -60
MSVS_ASM_NEAR32 ~ 'NEAR32'
MSVS_ASM_NEAR32 ~ 'near32'
:lexeme ~ <MSVS_ASM_OFFSET>              priority => -60
MSVS_ASM_OFFSET ~ 'OFFSET'
MSVS_ASM_OFFSET ~ 'offset'
:lexeme ~ <MSVS_ASM_PLUS>                priority => -60
MSVS_ASM_PLUS ~ '+'
:lexeme ~ <MSVS_ASM_PTR>                 priority => -60
MSVS_ASM_PTR ~ 'PTR'
MSVS_ASM_PTR ~ 'ptr'
:lexeme ~ <MSVS_ASM_QWORD>               priority => -60
MSVS_ASM_QWORD ~ 'QWORD'
MSVS_ASM_QWORD ~ 'qword'
:lexeme ~ <MSVS_ASM_REAL10>              priority => -60
MSVS_ASM_REAL10 ~ 'REAL10'
MSVS_ASM_REAL10 ~ 'real10'
:lexeme ~ <MSVS_ASM_REAL4>               priority => -60
MSVS_ASM_REAL4 ~ 'REAL4'
MSVS_ASM_REAL4 ~ 'real4'
:lexeme ~ <MSVS_ASM_REAL8>               priority => -60
MSVS_ASM_REAL8 ~ 'REAL8'
MSVS_ASM_REAL8 ~ 'real8'
:lexeme ~ <MSVS_ASM_WORD>                priority => -60
MSVS_ASM_WORD ~ 'WORD'
MSVS_ASM_WORD ~ 'word'
:lexeme ~ <MSVS_ASM_TR7>                 priority => -60
MSVS_ASM_TR7 ~ 'TR7'
MSVS_ASM_TR7 ~ 'tr7'
:lexeme ~ <MSVS_ASM_TR6>                 priority => -60
MSVS_ASM_TR6 ~ 'TR6'
MSVS_ASM_TR6 ~ 'tr6'
:lexeme ~ <MSVS_ASM_TR5>                 priority => -60
MSVS_ASM_TR5 ~ 'TR5'
MSVS_ASM_TR5 ~ 'tr5'
:lexeme ~ <MSVS_ASM_TR4>                 priority => -60
MSVS_ASM_TR4 ~ 'TR4'
MSVS_ASM_TR4 ~ 'tr4'
:lexeme ~ <MSVS_ASM_TR3>                 priority => -60
MSVS_ASM_TR3 ~ 'TR3'
MSVS_ASM_TR3 ~ 'tr3'
:lexeme ~ <MSVS_ASM_THIS>                priority => -60
MSVS_ASM_THIS ~ 'THIS'
MSVS_ASM_THIS ~ 'this'
:lexeme ~ <MSVS_ASM_TBYTE>               priority => -60
MSVS_ASM_TBYTE ~ 'TBYTE'
MSVS_ASM_TBYTE ~ 'tbyte'
:lexeme ~ <MSVS_ASM_SWORD>               priority => -60
MSVS_ASM_SWORD ~ 'SWORD'
MSVS_ASM_SWORD ~ 'sword'
:lexeme ~ <MSVS_ASM_SS>                  priority => -60
MSVS_ASM_SS ~ 'SS'
MSVS_ASM_SS ~ 'ss'
:lexeme ~ <MSVS_ASM_SP>                  priority => -60
MSVS_ASM_SP ~ 'SP'
MSVS_ASM_SP ~ 'sp'
:lexeme ~ <MSVS_ASM_SI>                  priority => -60
MSVS_ASM_SI ~ 'SI'
MSVS_ASM_SI ~ 'si'
:lexeme ~ <MSVS_ASM_SDWORD>              priority => -60
MSVS_ASM_SDWORD ~ 'SDWORD'
MSVS_ASM_SDWORD ~ 'sdword'
:lexeme ~ <MSVS_ASM_SBYTE>               priority => -60
MSVS_ASM_SBYTE ~ 'SBYTE'
MSVS_ASM_SBYTE ~ 'sbyte'

##########################################################
# GCC EXTENSIONS
#
# Copyright 2002-2009 ISP RAS (http://www.ispras.ru), UniTESK Lab (http://www.unitesk.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# @author <A href="mailto:demakov@ispras.ru">Alexey Demakov</A>
# @author <A href="mailto:hed@ispras.ru">Alexey Khoroshilov</A>
# @version $Id$
#
##########################################################
gccBuiltinType ::= gccTypeof
                 | GCC_BUILTIN_VA_LIST

gccAsmStatement ::= gccAsmExpression SEMICOLON

gccAsmExpression ::= GCC_ASM LPAREN expression RPAREN
                   | GCC_ASM LPAREN RPAREN
                   | GCC_ASM LPAREN expression gccAsmInnerOperandList RPAREN
                   | GCC_ASM typeQualifier LPAREN expression RPAREN
                   | GCC_ASM typeQualifier LPAREN expression gccAsmInnerOperandList RPAREN
                   | GCC_ASM GOTO LPAREN expression gccAsmInnerOperandList gccAsmInnerLabelList RPAREN

gccAsmClobberList ::= gccAsmClobber | gccAsmClobberList COMMA gccAsmClobber

gccAsmOperandList ::= gccAsmOperand | gccAsmOperandList COMMA gccAsmOperand

gccAsmInnerClobberList ::= COLON gccAsmClobberList

gccAsmInnerOperandList2 ::= COLON
                          | COLON gccAsmInnerClobberList
                          | COLON gccAsmOperandList
                          | COLON gccAsmOperandList gccAsmInnerClobberList

gccAsmInnerOperandList ::= COLON
                         | COLON gccAsmInnerOperandList2
                         | COLON gccAsmOperandList
                         | COLON gccAsmOperandList gccAsmInnerOperandList2

gccAsmInnerLabelList ::= COLON
                       | COLON IDENTIFIER_UNAMBIGUOUS
                       | gccAsmInnerLabelList COMMA IDENTIFIER_UNAMBIGUOUS

gccAsmOperandPrefix ::= LBRACKET IDENTIFIER_UNAMBIGUOUS RBRACKET

gccAsmOperand ::= string LPAREN expression RPAREN
                | gccAsmOperandPrefix string LPAREN expression RPAREN

gccAsmClobber ::= string

gccStatementExpression ::= LPAREN compoundStatement RPAREN

gccArrayTypeModifier ::= typeQualifier

# @since 2.6.264
# for error handling: second assignmentExpression is always last parameter name
gccBuiltinVaStart ::= GCC_BUILTIN_VA_START
                      LPAREN
                      assignmentExpression
                      COMMA
                      assignmentExpression
                      RPAREN

# @since 2.6.264
gccBuiltinVaEnd ::= GCC_BUILTIN_VA_END
                    LPAREN
                    assignmentExpression
                    RPAREN

gccBuiltinVaArg ::= GCC_BUILTIN_VA_ARG
                    LPAREN
                    assignmentExpression
                    COMMA
                    typeName
                    RPAREN

gccTypeof ::= GCC_TYPEOF LPAREN typeName RPAREN
            | GCC_TYPEOF LPAREN assignmentExpression RPAREN

gccBuiltinOffsetof ::= GCC_BUILTIN_OFFSETOF LPAREN typeName COMMA offsetofMemberDesignator RPAREN

offsetofMemberDesignator ::=   IDENTIFIER_UNAMBIGUOUS
                               | offsetofMemberDesignator DOT IDENTIFIER_UNAMBIGUOUS
                               | offsetofMemberDesignator LBRACKET expression RBRACKET

#
# Microsoft Extensions
#
msvsAttribute ::= MSVS_ASM | MSVS_FASTCALL | MSVS_BASED | MSVS_CDECL | MSVS_CLRCALL | MSVS_STDCALL | MSVS_THISCALL

msvsBuiltinType ::=  MSVS_INT8
                  | MSVS_INT16
                  | MSVS_INT32
                  | MSVS_INT64

msvsAsmStatementDirectiveList ::= msvsAsmDirective+

msvsAsmStatement ::= MSVS_ASM msvsAsmDirective
                   | MSVS_ASM
                     LCURLY
                     msvsAsmStatementDirectiveList
                     RCURLY

msvsAsmDirective ::= msvsAsmLabelDef msvsAsmSegmentDirective
                   | msvsAsmSegmentDirective
                   | msvsAsmLabelDef

msvsAsmLabelDef ::= IDENTIFIER_UNAMBIGUOUS COLON
                  | IDENTIFIER_UNAMBIGUOUS COLON COLON
                  | MSVS_AT MSVS_AT COLON

#
# msvsAsmSegmentDirective ::=   msvsAsmInstruction
#                                | msvsAsmDataDirective
#                                | msvsAsmControlDirective
#                                | msvsAsmStartupDirective
#                                | msvsAsmExitDirective
#                                | msvsAsmOffsetDirective
#                                | msvsAsmLabelDirective
#                                | msvsAsmProcDirective
#                                  ( msvsAsmLocalDirective )*
#                                  ( msvsAsmDirective )*
#                                  msvsAsmEndpDirective
#                                | msvsAsmInvokeDirective
#                                | msvsAsmGeneralDirective
#
# The full MASM instruction set is not supported.
#
msvsAsmSegmentDirective ::=   msvsAsmInstruction

msvsAsmExprList ::= msvsAsmExpr
                  | msvsAsmExprList COMMA msvsAsmExpr

msvsAsmInstruction ::= msvsAsmInstrPrefix msvsAsmMnemonic msvsAsmExprList
                     | msvsAsmInstrPrefix msvsAsmMnemonic
                     | msvsAsmMnemonic msvsAsmExprList
                     | msvsAsmMnemonic

msvsAsmInstrPrefix ::= MSVS_ASM_REP | MSVS_ASM_REPE | MSVS_ASM_REPZ | MSVS_ASM_REPNE | MSVS_ASM_REPNZ | MSVS_ASM_LOCK

msvsAsmMnemonic ::= IDENTIFIER_UNAMBIGUOUS | MSVS_ASM_AND | MSVS_ASM_MOD | MSVS_ASM_NOT | MSVS_ASM_OR | MSVS_ASM_SEG | MSVS_ASM_SHL | MSVS_ASM_SHLD | MSVS_ASM_MOV | MSVS_ASM_SHR | MSVS_ASM_XOR

#
# msvsAsmExpr ::=   MSVS_ASM_SHORT  msvsAsmExpr05
#                   | msvsAsmDotType  msvsAsmExpr01
#                   | MSVS_ASM_OPATTR msvsAsmExpr01
#                   | msvsAsmExpr01
#
# The full MASM instruction set is not supported.
#/
msvsAsmExpr ::= msvsAsmExpr01

msvsAsmExpr01 ::=  msvsAsmExpr01 MSVS_ASM_OR  msvsAsmExpr02
                    | msvsAsmExpr01 MSVS_ASM_XOR msvsAsmExpr02
                    | msvsAsmExpr02

msvsAsmExpr02 ::=   msvsAsmExpr02 MSVS_ASM_AND msvsAsmExpr03
                    | msvsAsmExpr03

msvsAsmExpr03 ::=   MSVS_ASM_NOT msvsAsmExpr04
                    | msvsAsmExpr04

msvsAsmExpr04 ::=   msvsAsmExpr04 MSVS_ASM_EQ msvsAsmExpr05
                    | msvsAsmExpr04 MSVS_ASM_NE msvsAsmExpr05
                    | msvsAsmExpr04 MSVS_ASM_LT msvsAsmExpr05
                    | msvsAsmExpr04 MSVS_ASM_LE msvsAsmExpr05
                    | msvsAsmExpr04 MSVS_ASM_GT msvsAsmExpr05
                    | msvsAsmExpr04 MSVS_ASM_GE msvsAsmExpr05
                    | msvsAsmExpr05

msvsAsmExpr05 ::=   msvsAsmExpr05 MSVS_ASM_PLUS msvsAsmExpr06
                    | msvsAsmExpr05 MSVS_ASM_MINUS msvsAsmExpr06
                    | msvsAsmExpr06

msvsAsmExpr06 ::=   msvsAsmExpr06 MSVS_ASM_STAR  msvsAsmExpr07
                    | msvsAsmExpr06 MSVS_ASM_SLASH msvsAsmExpr07
                    | msvsAsmExpr06 MSVS_ASM_MOD   msvsAsmExpr07
                    | msvsAsmExpr06 MSVS_ASM_SHR   msvsAsmExpr07
                    | msvsAsmExpr06 MSVS_ASM_SHL   msvsAsmExpr07
                    | msvsAsmExpr06 MSVS_ASM_MOV   msvsAsmExpr07
                    | msvsAsmExpr07

msvsAsmExpr07 ::=   MSVS_ASM_PLUS  msvsAsmExpr08
                    | MSVS_ASM_MINUS msvsAsmExpr08
                    | msvsAsmExpr08

msvsAsmExpr08 ::=   MSVS_ASM_HIGH     msvsAsmExpr09
                    | MSVS_ASM_LOW      msvsAsmExpr09
                    | MSVS_ASM_HIGHWORD msvsAsmExpr09
                    | MSVS_ASM_LOWWORD  msvsAsmExpr09
                    | msvsAsmExpr09

#
# .type could eat C lexemes DOT and IDENTIFIER_UNAMBIGUOUS. Since we do not really mind about
# MSVS __asm accuracy, this is splitted explicitely into '.' and '.type'
#
msvsAsmDotType ::= MSVS_ASM_DOT MSVS_ASM_TYPE

msvsAsmExpr09 ::=   MSVS_ASM_OFFSET   msvsAsmExpr10
                    | MSVS_ASM_SEG      msvsAsmExpr10
                    | MSVS_ASM_LROFFSET msvsAsmExpr10
                    | msvsAsmDotType    msvsAsmExpr10
                    | MSVS_ASM_THIS     msvsAsmExpr10
                    | msvsAsmExpr09 MSVS_ASM_PTR msvsAsmExpr10
                    | msvsAsmExpr09 MSVS_ASM_COLON   msvsAsmExpr10
                    | msvsAsmExpr10

msvsAsmExpr10 ::=   msvsAsmExpr10 MSVS_ASM_DOT msvsAsmExpr11
                    | msvsAsmExpr10 MSVS_ASM_LBRACKET msvsAsmExpr MSVS_ASM_RBRACKET
                    | msvsAsmExpr11

#
# msvsAsmExpr11 ::=   LPAREN msvsAsmExpr RPAREN
#                     | MSVS_ASM_LBRACKET msvsAsmExpr MSVS_ASM_RBRACKET
#                     | MSVS_ASM_WIDTH IDENTIFIER_UNAMBIGUOUS
#                     | MSVS_ASM_MASK  IDENTIFIER_UNAMBIGUOUS
#                     | MSVS_ASM_SIZE    msvsAsmSizeArg
#                     | MSVS_ASM_SIZEOF  msvsAsmSizeArg
#                     | MSVS_ASM_LENGTH   IDENTIFIER_UNAMBIGUOUS
#                     | MSVS_ASM_LENGTHOF IDENTIFIER_UNAMBIGUOUS
#                     | msvsAsmEecordConst
#                     | msvsAsmString
#                     | msvsAsmConstant
#                     | msvsAsmType
#                     | IDENTIFIER_UNAMBIGUOUS
#                     | MSVS_ASM_DOLLAR
#                     | msvsAsmSegmentRegister
#                     | msvsAsmRegister
#                     | MSVS_ASM_ST
#                     | MSVS_ASM_ST LPAREN msvsAsmExpr RPAREN
#
# The full MASM instruction set is not supported.
#
msvsAsmExpr11 ::=   LPAREN msvsAsmExpr RPAREN
                    | MSVS_ASM_LBRACKET msvsAsmExpr MSVS_ASM_RBRACKET
                    | msvsAsmConstant
                    | msvsAsmType
                    | IDENTIFIER_UNAMBIGUOUS
                    | MSVS_ASM_DOLLAR
                    | msvsAsmSegmentRegister
                    | msvsAsmRegister

msvsAsmType ::=   IDENTIFIER_UNAMBIGUOUS
                  | msvsAsmDistance
                  | msvsAsmDataType

msvsAsmDistance ::=   msvsAsmNearfar
                      | MSVS_ASM_NEAR16
                      | MSVS_ASM_NEAR32
                      | MSVS_ASM_FAR16
                      | MSVS_ASM_FAR32

msvsAsmNearfar ::= MSVS_ASM_NEAR | MSVS_ASM_FAR

msvsAsmDataType ::=   MSVS_ASM_BYTE
                       | MSVS_ASM_SBYTE
                       | MSVS_ASM_WORD
                       | MSVS_ASM_SWORD
                       | MSVS_ASM_DWORD
                       | MSVS_ASM_SDWORD
                       | MSVS_ASM_FWORD
                       | MSVS_ASM_QWORD
                       | MSVS_ASM_TBYTE
                       | MSVS_ASM_REAL4
                       | MSVS_ASM_REAL8
                       | MSVS_ASM_REAL10

msvsAsmSegmentRegister ::= MSVS_ASM_CS | MSVS_ASM_DS | MSVS_ASM_ES | MSVS_ASM_FS | MSVS_ASM_GS | MSVS_ASM_SS

msvsAsmRegister ::=   msvsAsmSpecialRegister
                      | msvsAsmGpRegister
                      | msvsAsmByteRegister

msvsAsmSpecialRegister ::=   MSVS_ASM_CR0 | MSVS_ASM_CR2 | MSVS_ASM_CR3
                              | MSVS_ASM_DR0 | MSVS_ASM_DR1 | MSVS_ASM_DR2 | MSVS_ASM_DR3 | MSVS_ASM_DR6 | MSVS_ASM_DR7
                              | MSVS_ASM_TR3 | MSVS_ASM_TR4 | MSVS_ASM_TR5 | MSVS_ASM_TR6 | MSVS_ASM_TR7

msvsAsmGpRegister ::=   MSVS_ASM_AX | MSVS_ASM_EAX | MSVS_ASM_BX | MSVS_ASM_EBX | MSVS_ASM_CX | MSVS_ASM_ECX | MSVS_ASM_DX | MSVS_ASM_EDX
                         | MSVS_ASM_BP | MSVS_ASM_EBP | MSVS_ASM_SP | MSVS_ASM_ESP | MSVS_ASM_DI | MSVS_ASM_EDI | MSVS_ASM_SI | MSVS_ASM_ESI

msvsAsmByteRegister ::= MSVS_ASM_AL | MSVS_ASM_AH | MSVS_ASM_BL | MSVS_ASM_BH | MSVS_ASM_CL | MSVS_ASM_CH | MSVS_ASM_DL | MSVS_ASM_DH

msvsAsmConstant ::= I_CONSTANT

###############################################################################################
# Discard simple preprocessor directives (on one line - cpp output persist to get some of them)
# Too bad if AST.pm did not catched it after a pause lexeme
###############################################################################################
<Cpp style directive start> ~ '#'
<Cpp style directive interior single line> ~ [^\n]*
<Cpp style directive> ~ <Cpp style directive start> <Cpp style directive interior single line>
:discard ~ <Cpp style directive>

#####################
# G0 specific "tools"
#####################
<G0 identifier> ~ WS_any _IDENTIFIER WS_any
<_G0 number> ~ [\d]+
<G0 number> ~ WS_any <_G0 number> WS_any
<G0 string unit> ~ WS_any '"' STRING_LITERAL_INSIDE_any '"' WS_any
<G0 string> ~ <G0 string unit>+

<_G0 word> ~ [\w]+
<G0 word> ~ WS_any <_G0 word> WS_any
<G0 words> ~ <G0 word>+
#
# Same thing as <G0 string> but with <> instead of "
#
STRING_LITERAL_INSIDE2 ~ [^<>\\\n]
STRING_LITERAL_INSIDE2 ~ ES
STRING_LITERAL_INSIDE2_any ~ STRING_LITERAL_INSIDE2*
<G0 string unit 2> ~ WS_any '<' STRING_LITERAL_INSIDE2_any '>' WS_any
<G0 string 2> ~ <G0 string unit 2>
#
# G0 operators
#
<G0 mul assign> ~ WS_any '*=' WS_any 
<G0 div assign> ~ WS_any '/=' WS_any 
<G0 mod assign> ~ WS_any '%=' WS_any 
<G0 add assign> ~ WS_any '+=' WS_any 
<G0 sub assign> ~ WS_any '-=' WS_any 
<G0 left assign> ~ WS_any '<<=' WS_any 
<G0 right assign> ~ WS_any '>>=' WS_any 
<G0 and assign> ~ WS_any '&=' WS_any 
<G0 xor assign> ~ WS_any '^=' WS_any 
<G0 or assign> ~ WS_any '|=' WS_any 
<G0 or op> ~ WS_any '||' WS_any 
<G0 and op> ~ WS_any '&&' WS_any
<G0 vertical bar> ~ WS_any '|' WS_any
<G0 caret> ~ WS_any '^' WS_any
<G0 ampersand> ~ WS_any '&' WS_any
<G0 eq op> ~ WS_any '==' WS_any
<G0 ne op> ~ WS_any '!=' WS_any
<G0 less than> ~ WS_any '<' WS_any
<G0 greater than> ~ WS_any '>' WS_any
<G0 le op> ~ WS_any '<=' WS_any
<G0 ge op> ~ WS_any '>=' WS_any
<G0 left op> ~ WS_any '<<' WS_any
<G0 right op> ~ WS_any '>>' WS_any
<G0 plus> ~ WS_any '+' WS_any
<G0 hyphen> ~ WS_any '-' WS_any
<G0 star> ~ WS_any '*' WS_any
<G0 slash> ~ WS_any '/' WS_any
<G0 percent> ~ WS_any '%' WS_any
<G0 lparen> ~ WS_any '(' WS_any
<G0 rparen> ~ WS_any ')' WS_any
<G0 lcurly> ~ WS_any '{' WS_any
<G0 rcurly> ~ WS_any '}' WS_any
<G0 lbracket> ~ WS_any '[' WS_any
<G0 rbracket> ~ WS_any ']' WS_any
<G0 inc op> ~ WS_any '++' WS_any
<G0 dec op> ~ WS_any '--' WS_any
<G0 ptr op> ~ WS_any '->' WS_any
<G0 dot> ~ WS_any '.' WS_any
<G0 exclamation> ~ WS_any '!' WS_any
<G0 tilde> ~ WS_any '~' WS_any
<G0 generic> ~ WS_any '_Generic' WS_any
<G0 default> ~ WS_any 'default' WS_any
<G0 ellipsis> ~ WS_any '...' WS_any
<G0 sizeof> ~ WS_any 'sizeof' WS_any
<G0 alignof> ~ WS_any '_Alignof' WS_any
             | WS_any '__alignof__' WS_any
             | WS_any 'alignof__' WS_any
             | WS_any '__alignof' WS_any
             | WS_any 'alignof' WS_any
#
# G0 "separators"
#
<G0 comma> ~ WS_any ',' WS_any
<G0 equal> ~ WS_any '=' WS_any
<G0 colon> ~ WS_any ':' WS_any
<G0 semicolon> ~ WS_any ';' WS_any
<G0 question mark> ~ WS_any '?' WS_any

#
# G0 "constants"
#
<G0 I_CONSTANT> ~ HP H_many IS_maybe
                | BP B_many IS_maybe   # Gcc extension: binary constants
                | NZ D_any IS_maybe
                | '0' O_any IS_maybe
                | CP_maybe QUOTE I_CONSTANT_INSIDE_many QUOTE
<G0 F_CONSTANT> ~ D_many E FS_maybe
                | D_any '.' D_many E_maybe FS_maybe
                | D_many '.' E_maybe FS_maybe
                | HP H_many P FS_maybe
                | HP H_any '.' H_many P FS_maybe
                | HP H_many '.' P FS_maybe
<G0 constant> ~ <G0 I_CONSTANT>
              | <G0 F_CONSTANT>
              | <G0 identifier>

#############################################################################################
# Discard MSVS __pragma stuff. It can happen in a lot of place, even in places not compatible
# with the C grammar
#############################################################################################
<MSVS pragma> ~ '__pragma' <G0 lparen> <MSVS pragma directive> <G0 rparen>
<MSVS pragma directive> ~ <MSVS pragma directive alloc_text>
                        | <MSVS pragma directive auto_inline>
                        | <MSVS pragma directive common seg>
                        | <MSVS pragma directive check_stack>
                        | <MSVS pragma directive comment>
                        | <MSVS pragma directive component>
                        | <MSVS pragma directive conform>
                        | <MSVS pragma directive deprecated>
                        | <MSVS pragma directive detect_mismatch>
                        | <MSVS pragma directive fenv_access>
                        | <MSVS pragma directive float_control>
                        | <MSVS pragma directive fp_contract>
                        | <MSVS pragma directive function>
                        | <MSVS pragma directive hdrstop>
                        | <MSVS pragma directive include_alias>
                        | <MSVS pragma directive inline_depth>
                        | <MSVS pragma directive inline_recursion>
                        | <MSVS pragma directive intrinsic>
                        | <MSVS pragma directive loop>
                        | <MSVS pragma directive make_public>
                        | <MSVS pragma directive managed>
                        | <MSVS pragma directive unmanaged>
                        | <MSVS pragma directive message>
                        # TODO - only the parallel if() is causing trouble
			# | <MSVS pragma directive omp>
			| <MSVS pragma directive once>
			| <MSVS pragma directive optimize>
			| <MSVS pragma directive pack>
			| <MSVS pragma directive pointers_to_members>
			| <MSVS pragma directive pop_macro>
			| <MSVS pragma directive push_macro>
			| <MSVS pragma directive region>
			| <MSVS pragma directive endregion>
			| <MSVS pragma directive runtime_checks>
			| <MSVS pragma directive section>
			| <MSVS pragma directive setlocale>
			| <MSVS pragma directive strict_gs_check>
			| <MSVS pragma directive vtordisp>
                        | <MSVS pragma directive warning>

# alloc_text( "textsection", function1, ... )
<MSVS pragma directive alloc_text> ~ 'alloc_text' <G0 lparen> <MSVS pragma directive alloc_text interior> <G0 rparen>
<MSVS pragma directive alloc_text interior> ~ <G0 string>
                                            | <MSVS pragma directive alloc_text interior> <G0 comma> <MSVS pragma directive alloc_text identifier list>
<MSVS pragma directive alloc_text identifier list> ~ <G0 identifier>
                                                   | <MSVS pragma directive alloc_text identifier list> <G0 comma> <G0 identifier>

# auto_inline( [{on | off}] )
<MSVS pragma directive auto_inline> ~ 'auto_inline' <G0 lparen> <G0 rparen>
                                    | 'auto_inline' <G0 lparen> <MSVS pragma directive auto_inline interior> <G0 rparen>

<MSVS pragma directive auto_inline interior> ~ 'on' | 'off'


# warning( warning-specifier : warning-number-list [; warning-specifier : warning-number-list...] ) 
# warning( push[ ,n ] ) 
# warning( pop )
<MSVS pragma directive warning> ~ 'warning' <G0 lparen> <MSVS pragma directive warning interior> <G0 rparen>
<MSVS pragma directive warning interior> ~ <MSVS pragma directive warning interior specifier list>
                                         | <MSVS pragma directive warning interior push>
                                         | <MSVS pragma directive warning interior pop>
<MSVS pragma directive warning interior specifier list> ~ <MSVS pragma directive warning interior specifier>
                                                        | <MSVS pragma directive warning interior specifier list> <G0 semicolon> <MSVS pragma directive warning interior specifier>
<MSVS pragma directive warning interior specifier keyword> ~ '1' | '2' | '3' | '4'
                                                           | 'default'
                                                           | 'disable'
                                                           | 'error'
                                                           | 'once'
                                                           | 'suppress'
<MSVS pragma directive warning interior specifier> ~ <MSVS pragma directive warning interior specifier keyword> <G0 colon> <MSVS pragma directive warning interior specifier number list>
<MSVS pragma directive warning interior specifier number list> ~ <G0 number>
                                                               | <MSVS pragma directive warning interior specifier number list> WS_many <G0 number>
<MSVS pragma directive warning interior push> ~ 'push'
                                              | 'push' <G0 comma> <G0 number>
<MSVS pragma directive warning interior pop> ~ 'pop'

# [bss|code]_seg( [ [ { push | pop }, ] [ identifier, ] ] [ "segment-name" [, "segment-class" ] )
<MSVS pragma directive common seg push or pop> ~ 'push' | 'pop'
<MSVS pragma directive common seg interior 1> ~ <MSVS pragma directive common seg push or pop>
                                              | <MSVS pragma directive common seg push or pop> <G0 comma> <G0 identifier>
                                              | <G0 identifier>
<MSVS pragma directive common seg interior 2> ~ <G0 string>
                                              | <G0 string> <G0 comma> <G0 string>
<MSVS pragma directive common seg interior> ~ <MSVS pragma directive common seg interior 1>
                                            | <MSVS pragma directive common seg interior 2>
                                            | <MSVS pragma directive common seg interior 1> <G0 comma> <MSVS pragma directive common seg interior 2>
<MSVS pragma directive common seg> ~ <MSVS pragma directive common seg keyword> <G0 lparen> <G0 rparen>
                                   | <MSVS pragma directive common seg keyword> <G0 lparen> <MSVS pragma directive common seg interior> <G0 rparen>
<MSVS pragma directive common seg keyword> ~ 'bss_seg' | 'code_seg' | 'const_seg' | 'data_seg'

# check_stack([ {on | off}] )
# check_stack{+|-}
<MSVS pragma directive check_stack interior> ~ 'on' | 'off' | '+' | '-'
<MSVS pragma directive check_stack> ~ 'check_stack' <G0 lparen> <G0 rparen>
                                    | 'check_stack' <G0 lparen> <MSVS pragma directive check_stack interior> <G0 rparen>

# comment( comment-type [,"commentstring"] )
<MSVS pragma directive comment interior type> ~ 'compiler' | 'exestr' | 'lib' | 'linker' | 'user'
<MSVS pragma directive comment interior> ~ <MSVS pragma directive comment interior type>
                                         | <MSVS pragma directive comment interior type> <G0 comma> <G0 string>
<MSVS pragma directive comment> ~ 'comment' <G0 lparen> <MSVS pragma directive comment interior> <G0 rparen>

# component( browser, { on | off }[, references [, name ]] )
# component( minrebuild, on | off ) 
# component( mintypeinfo, on | off )
# Note: we use <G0 identifier> for name, which is ok, since it refers a storage type, that matches <G0 identifier>

<MSVS pragma directive component interior name> ~ <G0 identifier>
                                                | <G0 string>
<MSVS pragma directive component interior browser on off> ~ 'on' | 'off'
<MSVS pragma directive component interior browser> ~ 'browser' <G0 comma> <MSVS pragma directive component interior browser on off>
                                                   | 'browser' <G0 comma> <MSVS pragma directive component interior browser on off> <G0 comma> 'references'
                                                   | 'browser' <G0 comma> <MSVS pragma directive component interior browser on off> <G0 comma> 'references' <G0 comma> <MSVS pragma directive component interior name>
<MSVS pragma directive component interior minrebuild> ~ 'minrebuild' <G0 comma> <MSVS pragma directive component interior browser on off>
<MSVS pragma directive component interior mintypeinfo> ~ 'mintypeinfo' <G0 comma> <MSVS pragma directive component interior browser on off>
<MSVS pragma directive component interior> ~ <MSVS pragma directive component interior browser>
                                           | <MSVS pragma directive component interior minrebuild>
                                           | <MSVS pragma directive component interior mintypeinfo>
<MSVS pragma directive component> ~ 'component' <G0 lparen> <MSVS pragma directive component interior> <G0 rparen>

# conform(name [, show ] [, on | off ] [ [, push | pop ] [, identifier ] ] )
# Note: the examples do not conform to this specification, i.e.:
# conform(forScope, push, x, on)
# Therefore we consider that the components show, on/off, push/pop and identifier could appear in any order (and in fact as many times as needed)

<MSVS pragma directive conform interior name> ~ 'forScope'
<MSVS pragma directive conform interior show> ~ 'show'
<MSVS pragma directive conform interior on off> ~ 'on' | 'off'
<MSVS pragma directive conform interior push pop> ~ 'push' | 'pop'
<MSVS pragma directive conform interior> ~ <MSVS pragma directive conform interior name>
                                           | <MSVS pragma directive conform interior name> <G0 comma> <MSVS pragma directive conform interior optional>
<MSVS pragma directive conform interior optional unit> ~ <MSVS pragma directive conform interior show>
                                                         | <MSVS pragma directive conform interior on off>
                                                         | <MSVS pragma directive conform interior push pop>
                                                         | <G0 identifier>
<MSVS pragma directive conform interior optional> ~ <MSVS pragma directive conform interior optional unit>
                                                    | <MSVS pragma directive conform interior optional> <G0 comma> <MSVS pragma directive conform interior optional unit>
<MSVS pragma directive conform> ~ 'conform' <G0 lparen> <MSVS pragma directive conform interior> <G0 rparen>

# deprecated( identifier1 [,identifier2, ...] )
<MSVS pragma directive deprecated interior> ~ <G0 identifier>
                                            | <MSVS pragma directive deprecated interior> <G0 comma> <G0 identifier>
<MSVS pragma directive deprecated> ~ 'deprecated' <G0 lparen> <MSVS pragma directive deprecated interior> <G0 rparen>

# detect_mismatch( "name", "value")
<MSVS pragma directive detect_mismatch interior> ~ <G0 string> <G0 comma> <G0 string>
<MSVS pragma directive detect_mismatch> ~ 'detect_mismatch' <G0 lparen> <MSVS pragma directive detect_mismatch interior> <G0 rparen>

# fenv_access [ON | OFF]
# Are the parenthesis necessary ? don't know - assume not
# on or ON, off or OFF ? Assume all.
<MSVS pragma directive fenv_access interior> ~ 'on' | 'ON' | 'off' | 'OFF'
<MSVS pragma directive fenv_access> ~ 'fenv_access'
                                    | 'fenv_access' <G0 lparen> <G0 rparen>
                                    | 'fenv_access' <G0 lparen> <MSVS pragma directive fenv_access interior> <G0 rparen>

# float_control( value,setting [push] | push | pop )
<MSVS pragma directive float_control interior value> ~ 'precise' | 'except'
<MSVS pragma directive float_control interior setting> ~ 'on' | 'off'
<MSVS pragma directive float_control interior> ~ <MSVS pragma directive float_control interior value> <G0 comma> <MSVS pragma directive float_control interior setting> 
                                               | <MSVS pragma directive float_control interior value> <G0 comma> <MSVS pragma directive float_control interior setting> WS_any 'push'
                                               | 'push'
                                               | 'pop'
<MSVS pragma directive float_control> ~ 'float_control' <G0 lparen> <MSVS pragma directive float_control interior> <G0 rparen>

# fp_contract [ON | OFF]
# Are the parenthesis necessary ? don't know - assume not
# on or ON, off or OFF ? Assume all.
<MSVS pragma directive fp_contract interior> ~ 'on' | 'ON' | 'off' | 'OFF'
<MSVS pragma directive fp_contract> ~ 'fp_contract'
                                    | 'fp_contract' <G0 lparen> <G0 rparen>
                                    | 'fp_contract' <G0 lparen> <MSVS pragma directive fp_contract interior> <G0 rparen>

# function( function1 [,function2, ...] )
<MSVS pragma directive function interior> ~ <G0 identifier>
                                            | <MSVS pragma directive function interior> <G0 comma> <G0 identifier>
<MSVS pragma directive function> ~ 'function' <G0 lparen> <MSVS pragma directive function interior> <G0 rparen>

# hdrstop [( "filename" )]
<MSVS pragma directive hdrstop interior> ~ <G0 string>
<MSVS pragma directive hdrstop> ~ 'hdrstop'
                                | 'hdrstop' <G0 lparen> <MSVS pragma directive hdrstop interior> <G0 rparen>

# include_alias( "long_filename", "short_filename" )
# include_alias( <long_filename>, <short_filename> )
<MSVS pragma directive include_alias interior> ~ <G0 string> <G0 comma> <G0 string>
                                               | <G0 string 2> <G0 comma> <G0 string 2>
<MSVS pragma directive include_alias> ~ 'include_alias' <G0 lparen> <MSVS pragma directive include_alias interior> <G0 rparen>

# inline_depth( [n] )
<MSVS pragma directive inline_depth interior> ~ <G0 number>
<MSVS pragma directive inline_depth> ~ 'inline_depth' <G0 lparen> <G0 rparen>
                                     | 'inline_depth' <G0 lparen> <MSVS pragma directive inline_depth interior> <G0 rparen>

# inline_recursion( [{on | off}] )
<MSVS pragma directive inline_recursion interior> ~ 'on' | 'off'
<MSVS pragma directive inline_recursion> ~ 'inline_recursion' <G0 lparen> <G0 rparen>
                                     | 'inline_recursion' <G0 lparen> <MSVS pragma directive inline_recursion interior> <G0 rparen>

# intrinsic( function1 [,function2, ...] )
<MSVS pragma directive intrinsic interior> ~ <G0 identifier>
                                            | <MSVS pragma directive intrinsic interior> <G0 comma> <G0 identifier>
<MSVS pragma directive intrinsic> ~ 'intrinsic' <G0 lparen> <MSVS pragma directive intrinsic interior> <G0 rparen>

# loop( hint_parallel(n) )
# loop( no_vector )
# loop( ivdep )
<MSVS pragma directive loop interior> ~ 'hint_parallel' <G0 lparen> <G0 number> <G0 rparen>
                                      | 'no_vector'
                                      | 'ivdep'
<MSVS pragma directive loop> ~ 'loop' <G0 lparen> <MSVS pragma directive loop interior> <G0 rparen>

# make_public(type)
<MSVS pragma directive make_public interior> ~ <G0 identifier>
<MSVS pragma directive make_public> ~ 'make_public' <G0 lparen> <MSVS pragma directive make_public interior> <G0 rparen>

# managed
# managed([push,] on | off)
# managed(pop)
<MSVS pragma directive managed interior on off> ~ 'on' | 'off'
<MSVS pragma directive managed interior> ~ 'push' <G0 comma> <MSVS pragma directive managed interior on off>
                                         | <MSVS pragma directive managed interior on off>
                                         | 'pop'
<MSVS pragma directive managed> ~ 'managed'
                                | 'managed' <G0 lparen> <G0 rparen>
                                | 'managed' <G0 lparen> <MSVS pragma directive managed interior> <G0 rparen>

# unmanaged
<MSVS pragma directive unmanaged> ~ 'unmanaged'
                                  | 'unmanaged' <G0 lparen> <G0 rparen>

# message( messagestring )
<MSVS pragma directive message interior> ~ <G0 string>
<MSVS pragma directive message> ~ 'message' <G0 lparen> <MSVS pragma directive message interior> <G0 rparen>

# once
<MSVS pragma directive once> ~ 'once'
                             | 'once' <G0 lparen> <G0 rparen>

# optimize( "[optimization-list]", {on | off} )
#  Note: "[optimization-list]" should contains only specified characters. We do not mind and say this is a string.
<MSVS pragma directive optimize interior optimizationList> ~  <G0 string>
<MSVS pragma directive optimize interior on off> ~ 'on' | 'off'
<MSVS pragma directive optimize interior> ~ <MSVS pragma directive optimize interior optimizationList> <G0 comma> <MSVS pragma directive optimize interior on off>
<MSVS pragma directive optimize> ~ 'optimize' <G0 lparen> <MSVS pragma directive optimize interior> <G0 rparen>

# pack( [ show ] | [ push | pop ] [, identifier ] , n  )
<MSVS pragma directive pack interior show> ~ 'show'
<MSVS pragma directive pack interior 1> ~ <MSVS pragma directive pack interior show>
<MSVS pragma directive pack interior push pop> ~ 'push' | 'pop'
<MSVS pragma directive pack interior 21> ~ <MSVS pragma directive pack interior push pop>
                                         | <G0 identifier>
                                         | <MSVS pragma directive pack interior push pop> <G0 comma> <G0 identifier>
<MSVS pragma directive pack interior 2> ~ <G0 number>
                                        | <MSVS pragma directive pack interior 21> <G0 comma> <G0 number>
<MSVS pragma directive pack interior> ~ <MSVS pragma directive pack interior 1>
                                      | <MSVS pragma directive pack interior 2>
<MSVS pragma directive pack> ~ 'pack' <G0 lparen> <G0 rparen>
                             | 'pack' <G0 lparen> <MSVS pragma directive pack interior> <G0 rparen>

# pointers_to_members( pointer-declaration, [most-general-representation] )
<MSVS pragma directive pointers_to_members interior pointer declaration> ~ 'full_generality' | 'best_case'
<MSVS pragma directive pointers_to_members interior most general representation> ~ 'single_inheritance' | 'multiple_inheritance' | 'virtual_inheritance'
<MSVS pragma directive pointers_to_members interior> ~ <MSVS pragma directive pointers_to_members interior pointer declaration>
                                                     | <MSVS pragma directive pointers_to_members interior pointer declaration> <G0 comma> <MSVS pragma directive pointers_to_members interior most general representation>
<MSVS pragma directive pointers_to_members> ~ 'pointers_to_members' <G0 lparen> <MSVS pragma directive pointers_to_members interior> <G0 rparen>

# pop_macro("macro_name")
<MSVS pragma directive pop_macro> ~ 'pop_macro' <G0 lparen> <G0 string> <G0 rparen>

# push_macro("macro_name")
<MSVS pragma directive push_macro> ~ 'push_macro' <G0 lparen> <G0 string> <G0 rparen>

# region [name]
<MSVS pragma directive region interior> ~ <G0 identifier>
<MSVS pragma directive region> ~ 'region'
                               | 'region' <G0 lparen> <G0 rparen>
                               | 'region' <G0 lparen> <MSVS pragma directive region interior> <G0 rparen>

# endregion [name]
<MSVS pragma directive endregion interior> ~ <G0 identifier>
<MSVS pragma directive endregion> ~ 'endregion'
                                  | 'endregion' <G0 lparen> <G0 rparen>
                                  | 'endregion' <G0 lparen> <MSVS pragma directive endregion interior> <G0 rparen>

# optimize( "[runtime_checks]", {restore | off} )
#  Note: "[runtime_checks]" should contains only specified characters. We do not mind and say this is a string.
<MSVS pragma directive runtime_checks interior optimizationList> ~  <G0 string>
<MSVS pragma directive runtime_checks interior on off> ~ 'restore' | 'off'
<MSVS pragma directive runtime_checks interior> ~ <MSVS pragma directive runtime_checks interior optimizationList> <G0 comma> <MSVS pragma directive runtime_checks interior on off>
<MSVS pragma directive runtime_checks> ~ 'runtime_checks' <G0 lparen> <MSVS pragma directive runtime_checks interior> <G0 rparen>

# section( "section-name" [, attributes] )
<MSVS pragma directive section interior attribute> ~ 'read' | 'write' | 'execute' | 'shared' | 'nopage' | 'nocache' | 'discard' | 'remove'
<MSVS pragma directive section interior attribute list> ~ <MSVS pragma directive section interior attribute>
                                                        | <MSVS pragma directive section interior attribute list> <G0 comma> <MSVS pragma directive section interior attribute>
<MSVS pragma directive section interior> ~ <G0 string>
                                         | <G0 string> <G0 comma> <MSVS pragma directive section interior attribute list>
<MSVS pragma directive section> ~ 'section' <G0 lparen> <MSVS pragma directive section interior> <G0 rparen>

# setlocale( "[locale-string]" )
<MSVS pragma directive setlocale interior> ~ <G0 string>
<MSVS pragma directive setlocale> ~ 'setlocale' <G0 lparen> <MSVS pragma directive setlocale interior> <G0 rparen>

# strict_gs_check([push,] on )
# strict_gs_check([push,] off )
# strict_gs_check(pop)
<MSVS pragma directive strict_gs_check interior on off> ~ 'on' | 'off'
<MSVS pragma directive strict_gs_check interior> ~ <MSVS pragma directive strict_gs_check interior on off>
                                                 | 'push' <G0 comma> <MSVS pragma directive strict_gs_check interior on off>
                                                 | 'pop'
<MSVS pragma directive strict_gs_check> ~ 'strict_gs_check' <G0 lparen> <MSVS pragma directive strict_gs_check interior> <G0 rparen>

# vtordisp([push,] n)
# vtordisp(pop)
# vtordisp()
# vtordisp([push,] {on | off})
<MSVS pragma directive vtordisp interior on off number> ~ 'on' | 'off' | <G0 number>
<MSVS pragma directive vtordisp interior> ~ <MSVS pragma directive vtordisp interior on off number>
                                          | 'push' <G0 comma> <MSVS pragma directive vtordisp interior on off number>
                                          | 'pop'
<MSVS pragma directive vtordisp> ~ 'vtordisp'
                                 | 'vtordisp' <G0 lparen> <G0 rparen>
                                 | 'vtordisp' <G0 lparen> <MSVS pragma directive vtordisp interior> <G0 rparen>

:discard ~ <MSVS pragma>

###############################
# Discard MSVS __declspec stuff
###############################
<MSVS declspec> ~ '__declspec' <G0 lparen> <MSVS declspec directive> <G0 rparen>
<MSVS declspec directive> ~ <MSVS declspec align>
                          | <MSVS declspec allocate>
                          | <MSVS declspec appdomain>
                          | <MSVS declspec deprecated>
                          | <MSVS declspec dllexport>
                          | <MSVS declspec dllimport>
                          | <MSVS declspec jitintrinsic>
                          | <MSVS declspec naked>
                          | <MSVS declspec noalias>
                          | <MSVS declspec noinline>
                          | <MSVS declspec noreturn>
                          | <MSVS declspec nothrow>
                          | <MSVS declspec novtable>
                          | <MSVS declspec process>
                          | <MSVS declspec property>
                          | <MSVS declspec restrict>
                          | <MSVS declspec safebuffers>
                          | <MSVS declspec selectany>
                          | <MSVS declspec thread>
                          | <MSVS declspec uuid>

# align(#)
<MSVS declspec align> ~ 'align' <G0 lparen> <G0 number> <G0 rparen>

# allocate("segname")
<MSVS declspec allocate> ~ 'allocate' <G0 lparen> <G0 string> <G0 rparen>

# appdomain
<MSVS declspec appdomain> ~ 'appdomain'

# deprecated
# deprecated()
# deprecated("text")
<MSVS declspec deprecated> ~ 'deprecated'
                           | 'deprecated' <G0 lparen> <G0 rparen>
                           | 'deprecated' <G0 lparen> <G0 string> <G0 rparen>

# dllexport
<MSVS declspec dllexport> ~ 'dllexport'

# dllimport
<MSVS declspec dllimport> ~ 'dllimport'

# jitintrinsic
<MSVS declspec jitintrinsic> ~ 'jitintrinsic'

# naked
<MSVS declspec naked> ~ 'naked'

# noalias
<MSVS declspec noalias> ~ 'noalias'

# noinline
<MSVS declspec noinline> ~ 'noinline'

# noreturn
<MSVS declspec noreturn> ~ 'noreturn'

# nothrow
<MSVS declspec nothrow> ~ 'nothrow'

# novtable
<MSVS declspec novtable> ~ 'novtable'

# process
<MSVS declspec process> ~ 'process'

# property([get|put]=function)
<MSVS declspec property interior get put> ~ 'get' | 'put'
<MSVS declspec property interior> ~ <MSVS declspec property interior get put> <G0 equal> <G0 identifier>
<MSVS declspec property interior list> ~ <MSVS declspec property interior>
                                       | <MSVS declspec property interior list> <G0 comma> <MSVS declspec property interior>
<MSVS declspec property> ~ 'property' <G0 lparen> <MSVS declspec property interior list> <G0 rparen>

# restrict
<MSVS declspec restrict> ~ 'restrict'

# safebuffers
<MSVS declspec safebuffers> ~ 'safebuffers'

# selectany
<MSVS declspec selectany> ~ 'selectany'

# thread
<MSVS declspec thread> ~ 'thread'

# uuid("ComObjectGUID")
<MSVS declspec uuid> ~ 'uuid' <G0 lparen> <G0 string> <G0 rparen>

:discard ~ <MSVS declspec>

#################################
# Discard GCC __attribute__ stuff
#################################
<GCC attribute keyword> ~ '__attribute__'
                        | '__attribute'

<GCC attribute> ~ <GCC attribute keyword> <G0 lparen> <G0 lparen> <G0 rparen> <G0 rparen>
                | <GCC attribute keyword> <G0 lparen> <G0 lparen> <GCC attribute list> <G0 rparen> <G0 rparen>

<GCC attribute list> ~ <GCC attribute unit>
                     | <GCC attribute list> <G0 comma> <GCC attribute unit>

<GCC attribute unit> ~ <G0 word>
                     | <G0 word> <G0 lparen> <G0 rparen>
                     | <G0 word> <G0 lparen> <GCC attribute parameters> <G0 rparen>

<GCC attribute parameters> ~ <G0 identifier>
                           | <G0 identifier> <G0 comma> <GCC attribute parameters expressions>
                           | <GCC attribute parameters expressions>

<GCC attribute parameters expressions> ~ <GCC attribute parameters expression>
                                       | <GCC attribute parameters expressions> <G0 comma> <GCC attribute parameters expression>

#
# Here comes the difficuly. This should be an expression.
# Since this is for :discard, we provide a G0 version of it.
# This is a brutal version:
# - typeName is replaced by <G0 words>
# - GCC extensions are ignored
#
<GCC attribute parameters expression> ~ <G0 expression>

<G0 expression>	~ <G0 assignmentExpression>
	        | <G0 expression> <G0 comma> <G0 assignmentExpression>

<G0 assignmentExpression> ~ <G0 conditionalExpression>
	                  | <G0 unaryExpression> <G0 assignmentOperator> <G0 assignmentExpression>

<G0 assignmentOperator>	~ <G0 equal>
	                | <G0 mul assign>
                	| <G0 div assign>
                	| <G0 mod assign>
                	| <G0 add assign>
                	| <G0 sub assign>
                	| <G0 left assign>
                	| <G0 right assign>
                	| <G0 and assign>
                	| <G0 xor assign>
                	| <G0 or assign>

<G0 conditionalExpression> ~ <G0 logicalOrExpression>
                           | <G0 logicalOrExpression> <G0 question mark> <G0 expression> <G0 colon> <G0 conditionalExpression>
                           | <G0 logicalOrExpression> <G0 question mark> <G0 colon> <G0 conditionalExpression>          # GCC Extension

<G0 logicalOrExpression> ~ <G0 logicalAndExpression>
                         | <G0 logicalOrExpression> <G0 or op> <G0 logicalAndExpression>

<G0 logicalAndExpression> ~ <G0 inclusiveOrExpression>
                          | <G0 logicalAndExpression> <G0 and op> <G0 inclusiveOrExpression>

<G0 inclusiveOrExpression> ~ <G0 exclusiveOrExpression>
                           | <G0 inclusiveOrExpression> <G0 vertical bar> <G0 exclusiveOrExpression>

<G0 exclusiveOrExpression> ~ <G0 andExpression>
                           | <G0 exclusiveOrExpression> <G0 caret> <G0 andExpression>

<G0 andExpression> ~ <G0 equalityExpression>
                   | <G0 andExpression> <G0 ampersand> <G0 equalityExpression>

<G0 equalityExpression> ~ <G0 relationalExpression>
                        | <G0 equalityExpression> <G0 eq op> <G0 relationalExpression>
                        | <G0 equalityExpression> <G0 ne op> <G0 relationalExpression>

<G0 relationalExpression> ~ <G0 shiftExpression>
                          | <G0 relationalExpression> <G0 less than> <G0 shiftExpression>
                          | <G0 relationalExpression> <G0 greater than> <G0 shiftExpression>
                          | <G0 relationalExpression> <G0 le op> <G0 shiftExpression>
                          | <G0 relationalExpression> <G0 ge op> <G0 shiftExpression>

<G0 shiftExpression> ~ <G0 additiveExpression>
                     | <G0 shiftExpression> <G0 left op> <G0 additiveExpression>
                     | <G0 shiftExpression> <G0 right op> <G0 additiveExpression>

<G0 additiveExpression>	~ <G0 multiplicativeExpression>
                        | <G0 additiveExpression> <G0 plus> <G0 multiplicativeExpression>
                        | <G0 additiveExpression> <G0 hyphen> <G0 multiplicativeExpression>

<G0 multiplicativeExpression> ~ <G0 castExpression>
                              | <G0 multiplicativeExpression> <G0 star> <G0 castExpression>
                              | <G0 multiplicativeExpression> <G0 slash> <G0 castExpression>
                              | <G0 multiplicativeExpression> <G0 percent> <G0 castExpression>

<G0 castExpression> ~ <G0 unaryExpression>
                    | <G0 lparen> <G0 words> <G0 rparen> <G0 castExpression>

<G0 unaryOperator> ~ <G0 ampersand>
                   | <G0 star>
                   | <G0 plus>
                   | <G0 hyphen>
                   | <G0 tilde>
                   | <G0 exclamation>

<G0 unaryExpression> ~ <G0 postfixExpression>
                     | <G0 inc op> <G0 unaryExpression>
                     | <G0 dec op> <G0 unaryExpression>
                     | <G0 unaryOperator> <G0 castExpression>
                     | <G0 sizeof> <G0 unaryExpression>
                     | <G0 sizeof> <G0 lparen> <G0 words> <G0 rparen>
                     | <G0 alignof> <G0 lparen> <G0 words> <G0 rparen>

<G0 postfixExpression>	~ <G0 primaryExpression>
                        | <G0 postfixExpression> <G0 lbracket> <G0 expression> <G0 rbracket>
                        | <G0 postfixExpression> <G0 lparen> <G0 rparen>
                        | <G0 postfixExpression> <G0 lparen> <G0 argumentExpressionList> <G0 rparen>
                        | <G0 postfixExpression> <G0 dot> <G0 identifier>
                        | <G0 postfixExpression> <G0 ptr op> <G0 identifier>
                        | <G0 postfixExpression> <G0 inc op>
                        | <G0 postfixExpression> <G0 dec op>
                        | <G0 lparen> <G0 words> <G0 rparen> <G0 lcurly> <G0 initializerList> <G0 rcurly>
                        | <G0 lparen> <G0 words> <G0 rparen> <G0 lcurly> <G0 initializerList> <G0 comma> <G0 rcurly>

<G0 primaryExpression> ~ <G0 identifier>
                       | <G0 constant>
                       | <G0 string>
                       | <G0 lparen> <G0 expression> <G0 rparen>
                       | <G0 genericSelection>

<G0 argumentExpressionList> ~ <G0 assignmentExpression>
                            | <G0 argumentExpressionList> <G0 comma> <G0 assignmentExpression>
                            | <G0 argumentExpressionList> <G0 comma>

<G0 genericSelection> ~ <G0 generic> <G0 lparen> <G0 assignmentExpression> <G0 comma> <G0 genericAssocList> <G0 rparen>

<G0 genericAssocList> ~ <G0 genericAssociation>
                      | <G0 genericAssocList> <G0 comma> <G0 genericAssociation>

<G0 genericAssociation>	~ <G0 words> <G0 colon> <G0 assignmentExpression>
                        | <G0 default> <G0 colon> <G0 assignmentExpression>

<G0 initializerList> ~ <G0 designation> <G0 initializer>
                     | <G0 initializer>
                     | <G0 identifier> <G0 colon> <G0 initializer>
                     | <G0 initializerList> <G0 comma> <G0 designation> <G0 initializer>
                     | <G0 initializerList> <G0 comma> <G0 initializer>

<G0 initializer> ~ <G0 lcurly> <G0 initializerList> <G0 rcurly>
                 | <G0 lcurly> <G0 initializerList> <G0 comma> <G0 rcurly>
                 | <G0 assignmentExpression>

<G0 designation> ~ <G0 designatorList> <G0 equal>

<G0 designatorList> ~ <G0 designator>+

<G0 designator>	~ <G0 lbracket> <G0 constantExpression> <G0 rbracket>
                | <G0 dot> <G0 identifier>
                | <G0 lbracket> <G0 constantExpression> <G0 ellipsis> <G0 constantExpression> <G0 rbracket> # GCC Extension

<G0 constantExpression>	~ <G0 conditionalExpression> # with constraints

:discard ~ <GCC attribute>
