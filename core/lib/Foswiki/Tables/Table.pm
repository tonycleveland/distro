# See bottom of file for copyright and pod

=begin TML

---+ package Foswiki::Tables::Table

Abstract model of a table in a topic, suitable for use with the tables parser.

A table consists of specification and a set of rows. The specification
gives type information about the columns it the table, to allow suitable
editors to be instantiated on cells.

The rows in the tables are divided into a block of (uneditable) header rows,
a block of (ediatble) body rows, and a block of (uneditable) footer rows.
Any of these blocks may be empty.

A Table object has the following public fields:
   * ={spec}= - if given, the =$spec= passed to the constructor (string)
   * ={rows}= - array of =Foswiki::Tables::Row= objects (or a subclass thereof)
   * ={number}= - an identifier for this table in the sequence of tables in the topic. =undef= until set by some external agency (e.g. the parser).
   * ={colTypes}= - each column format is stored in the {colTypes} array. Entries in this array have the following fields:
      * =type= - the type e.g. =text=, =radio=
      * =size= - the (unverified) size, e.g. =1=, =10x8= (defaults to 20 for =text=, =40x5= for =textarea= and =1= for any other type)
      * =initial_value= - everything after the second comma for =text=, =label= and =date=. The empty string otherwise.
      * =values= - array generated by treating everything after the second comma as a csv list.
   * ={headerrows}= - number of header rows in the table. If no header rows are specified in the spec this will be =undef=.
   * ={footerrows}= - number of footer rows in the table. If no footer rows are specified in the spec this will be =undef=.
=cut

package Foswiki::Tables::Table;

use strict;
use Assert;

use Foswiki::Tables::Row ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new($spec, $attrs)
Constructor
   * =$spec= - string representation of the macro parameters that apply to
     this table. Only required so that the table can be accurately serialised
     to TML (including controlling macro).
     Pass undef if the table will never be serialised.
   * =$attrs= - Foswiki::Attrs of any controlling tag, if the parser found one.
The following entries in attrs are supported:
   * =format= - The format of the cells in a row of the table. The format is
     defined like a table row, where the cell data specify the type for each
     cell. For example, =format="| text,16 | label |"=. Cells can be any of
     the following types:
      * =text, &lt;size&gt;, &lt;initial value&gt;= Simple text field. Initial value is optional.
      * =textarea, &lt;rows&gt;x&lt;columns&gt;, &lt;initial value&gt;=
        Multirow text box. Initial value is optional.
      * =select, &lt;size&gt;, &lt;option 1&gt;, &lt;option 2&gt;, etc=
        Select one from a list of choices.
      * =radio, &lt;size&gt;, &lt;option 1&gt;, &lt;option 2&gt;,= etc.
        Radio buttons. =size= indicates the number of buttons per line in edit mode.
      * =checkbox, &lt;size&gt;, &lt;option 1&gt;, &lt;option 2&gt;, etc=
        Checkboxes. =size= indicates the number of buttons per line in edit mode.
      * =label, 0, &lt;label text&gt;= Fixed label.
      * =row= The row number, automatically worked out.
      * =date, &lt;size&gt;, &lt;initial value&gt;, &lt;DHTML date format&gt;=
        Date. Initial value and date format are both optional.
   * =headerrows= - integer number of rows in the thead
   * =footerrows= - integer number of rows in the tfoot

=cut

sub new {
    my ( $class, $spec, $attrs ) = @_;

    my $this = bless(
        {
            spec   => $spec,
            rows   => [],
            number => undef
        },
        $class
    );
    if ( $attrs->{format} ) {
        $this->{colTypes} = $this->parseFormat( $attrs->{format} );
    }
    else {
        $this->{colTypes} = [];
    }

    $this->{headerrows} = $attrs->{headerrows};
    $this->{footerrows} = $attrs->{footerrows};

    return $this;
}

=begin TML

---++ ClassMethod row_class() -> $classname
Perl class used for constructing table rows (default Foswiki::Tables::Row)
Designed to be overridden in subclasses that want to use their own
subclass of Foswiki::Tables::Row for their rows.

=cut

sub row_class {
    return 'Foswiki::Tables::Row';
}

# Private - renumber the rows in the table after a row is moved
sub _renumber {
    my ( $this, $start ) = @_;
    $start ||= 0;
    for ( my $i = $start ; $i < $this->totalRows() ; $i++ ) {
        $this->{rows}->[$i]->number($i);
    }
}

=begin TML

---++ ClassMethod getMacro() -> $macroname
The macro name for additional attributes for this table class e.g
'EDITTABLE'.

=cut

sub getMacro {
    return 'TABLE';
}

=begin TML

---++ ObjectMethod finish()
Clean up for disposal

=cut

sub finish {
    my $this = shift;
    foreach my $row ( @{ $this->{rows} } ) {
        $row->finish();
    }
    undef( $this->{rows} );
    undef( $this->{colTypes} );
}

=begin TML

---++ ObjectMethod makeConsistent()

Check that the table is consistent with the spec, and fix it if not.
If there are header and footer rows defined in the the spec, there
have to be enough rows in the table for them. If fix is true, empty rows
will be added to flesh out to the required
number of rows.

Added rows will have the number of columns and initial data specified
by the format spec (minimum 1 colun)

=cut

sub makeConsistent {
    my ( $this, $fix ) = @_;

    my $minRows = $this->getHeaderRows() + $this->getFooterRows();
    if ( $this->totalRows() < $minRows ) {
        if ( defined $this->{headerrows} ) {
            while ( $this->totalRows() < $this->{headerrows} ) {
                my @vals =
                  map { "*$_->{initial_value}*" } @{ $this->{colTypes} };
                push( @vals, '*?*' ) unless scalar(@vals);
                my $newRow = $this->row_class->new( $this, '', '', \@vals );
                unshift( @{ $this->{rows} }, $newRow );
            }
        }
        while ( $this->totalRows() < $minRows ) {
            my @vals = map { $_->{initial_value} } @{ $this->{colTypes} };
            push( @vals, '' ) unless scalar(@vals);
            my $newRow = $this->row_class->new( $this, '', '', \@vals );
            push( @{ $this->{rows} }, $newRow );
        }
    }
}

=begin TML

---++ ObjectMethod totalRows() -> $integer

Return the total number of rows in the table (including header and
footer rows)

=cut

sub totalRows {
    return scalar( @{ $_[0]->{rows} } );
}

=begin TML

---++ ObjectMethod number([$set]) -> $number

Setter/getter for the table number. The table number uniquely identifies
the table within the context of a topic. The table number is undef until
it is set by some external agency.

=cut

sub number {
    my ( $this, $number ) = @_;

    $this->{number} = $number if defined $number;
    return $this->{number};
}

=begin TML

---++ ObjectMethod stringify()
Generate a TML representation of the table

=cut

sub stringify {
    my $this = shift;

    my $s = '';
    if ( $this->{spec} ) {
        $s .= "$this->{spec}\n";
    }
    foreach my $row ( @{ $this->{rows} } ) {
        $s .= $row->stringify() . "\n";
    }
    return $s;
}

=begin TML

---++ ObjectMethod getHeaderRows() -> $integer
Get the number of header rows on the table. Defaults to 0.

=cut

sub getHeaderRows {
    my $this = shift;
    return $this->{headerrows} || 0;
}

=begin TML

---++ ObjectMethod getFooterRows() -> $integer
Get the number of footer rows on the table.

=cut

sub getFooterRows {
    my $this = shift;
    return $this->{footerrows} || 0;
}

=begin TML

---++ ObjectMethod getID() -> $id
Generate a unique string ID that uniquely identifies this table within a topic.
Useful for identifying a table in the context of REST calls that modify the
table.

=cut

sub getID {
    my $this = shift;
    return $this->getMacro() . '_' . $this->number;
}

=begin TML

---++ ObjectMethod getFirstBodyRow() -> $integer
Get the 0-based row index of the first editable row after the header.
The row may not actually exist in the ={rows}=; this is just the
index of the row if it *does* exist.

=cut

sub getFirstBodyRow {
    my $this = shift;

    return $this->{headerrows} || 0;
}

=begin TML

---++ ObjectMethod getLastBodyRow() -> $integer
Get the 0-based row index of the last row before the footer.
The row may not actually exist in the ={rows}=; this is just the
index of the row if it *does* exist, given the current size of
the table.

=cut

sub getLastBodyRow {
    my $this = shift;

    my $n = $this->totalRows() - $this->getFooterRows() - 1;
    return ( $n < 0 ? 0 : $n );
}

=begin TML

---++ ObjectMethod getCellData([$row [, $col]]) -> $data

Get cell, row, column or entire table, depending on params.
   * If =$row= and =$col= are given, return the scalar stored in that
     cell.
   * If only =$row= is given, then return an array of the data in each
     column.
   * If $row is undef but $col is given, return an array of the data
     in that col.
   * If neither =$row= nor =$col= is given, return a 2D array of the
     cell data.

Only data which exists in the table is returned; columns missing
from rows will be filled out with undef.

=cut

sub getCellData {
    my ( $this, $row, $col ) = @_;

    ASSERT( !defined $row || $row >= 0 ) if DEBUG;
    ASSERT( !defined $col || $col >= 0 ) if DEBUG;

    my $d;
    if ( defined $row ) {
        if ( defined $col ) {
            return undef
              unless $row < $this->totalRows()
              && $col < scalar( @{ $this->{rows}->[$row]->{cols} } );
            $d = $this->{rows}->[$row]->{cols}->[$col]->{text};
        }
        else {

            # This entire row
            return undef unless $row < $this->totalRows();
            $d = [];
            foreach my $col ( @{ $this->{rows}->[$row]->{cols} } ) {
                push( @$d, $col->{text} );
            }
        }
    }
    elsif ( defined $col ) {

        # This entire col
        $d = [];
        foreach my $row ( @{ $this->{rows} } ) {
            if ( defined $row->{cols}->[$col] ) {
                push( @$d, $row->{cols}->[$col]->{text} );
            }
            else {
                push( @$d, undef );
            }
        }
    }
    else {

        # Entire table (row major)
        $d = [];
        foreach my $row ( @{ $this->{rows} } ) {
            my $c = [];
            foreach my $col ( @{ $row->{cols} } ) {
                push( @$c, $col->{text} );
            }
            push( @$d, $c );
        }
    }
    return $d;
}

=begin TML

---++ ObjectMethod getLabelRow() -> $rowobj
Get the last header row before the first body row. =undef= if there
is no label row.

=cut

sub getLabelRow() {
    my $this = shift;

    my $labelRow;
    foreach my $row ( @{ $this->{rows} } ) {
        if ( $row->isHeader() ) {
            $labelRow = $row;
        }
        else {

            # the last header row is always taken as the label row
            last;
        }
    }
    return $labelRow;
}

=begin TML

---++ ObjectMethod addRow($row [, $newRow [, $any_row]]) -> $rowObject
Construct and add a row _after_ the given row
    * =$row= - 0-based index of the row to add _after_
    * =$newRow= - the row to add. A new row will be created using the
     row_class if this is undefined.
   * =$any_row= - true to ignore header and footer constraints when adding
     rows.
If !$any_row, and $row is < 0, then adds to the start of the body rows.
If !$any_row and $row is after the last body row, then adds the
row to the end of the body rows.
if $any_row, and $row < 0, then adds to the start of the table.
If $any_row, and $row is after the last table row (including the footer)
the adds the row to the end of the table.

New rows are created with the number of columns specified in the format
spec for the table or, failing that, the width of row 0 of the
table.

If =$any_row= is false, the table will be made consistent (missing
header/footer rows added) before anything else is done.

Returns the new row.

=cut

sub addRow {
    my ( $this, $row, $newRow, $any_row ) = @_;

    $this->makeConsistent() unless $any_row;

    my $firstRow = ( $any_row ? 0 : $this->getFirstBodyRow() );
    $row = $firstRow - 1 if ( $row < $firstRow );
    my $lastRow = ( $any_row ? $this->totalRows() : $this->getLastBodyRow() );
    $row = $lastRow if ( $row > $lastRow );
    $any_row ||= 0;
    unless ($newRow) {
        my @vals = map { $_->{initial_value} } @{ $this->{colTypes} };

        # If necessary, widen up to the width of the first (hopefully
        # header) row
        my $count;
        if ( $this->totalRows() ) {
            my $count = scalar( @{ $this->{rows}->[0]->{cols} } );
            while ( scalar(@vals) < $count ) {
                push( @vals, '' );
            }
        }
        push( @vals, '' ) unless scalar(@vals);

        $newRow = $this->row_class->new( $this, '', '', \@vals );
    }

    if ( $row < 0 ) {
        unshift( @{ $this->{rows} }, $newRow );
        $row = 0;
    }
    elsif ( $row >= $this->totalRows() - 1 ) {
        push( @{ $this->{rows} }, $newRow );
        $row = $this->totalRows() - 1;
    }
    else {
        splice( @{ $this->{rows} }, $row + 1, 0, $newRow );
    }

    $this->_renumber($row);

    return $newRow;
}

# PACKAGE PRIVATE ObjectMethod pushRow($rowObject) -> $index
# Add a row to the end of the table (after the footer)
sub pushRow {
    my ( $this, $row ) = @_;

    $row->number( push( @{ $this->{rows} }, $row ) - 1 );
    return $row->number();
}

=begin TML

---++ ObjectMethod isEditableRow($row) -> $boolean
Return true if the given row is editable i.e. is a body row, and exists.

=cut

sub isEditableRow {
    my ( $this, $row ) = @_;

    return $row >= $this->getHeaderRows()
      && $row < ( $this->totalRows() - $this->getFooterRows() );
}

=begin TML

---++ deleteRow($row [, $any_row]) -> $boolean
Delete the given row
    * =$row= - 0-based index of the row to delete
    * =$any_row= - true to request deletion of header and footer rows
The row must exist. The row must be an editable row unless =$any_row= is true.

If =$any_row= is false, the table will be made consistent (missing
header/footer rows added) before anything else is done.

Returns true if the row was deleted.

=cut

sub deleteRow {
    my ( $this, $row, $any_row ) = @_;

    $this->makeConsistent() unless $any_row;

    return 0
      unless $this->isEditableRow($row)
      || $any_row && $row >= 0 && $row < $this->totalRows();
    my @dead = splice( @{ $this->{rows} }, $row, 1 );
    map { $_->finish() } @dead;
    $this->_renumber($row);
    return 1;
}

=begin TML

---++ ObjectMethod moveRow($from, $to [, $any_row]) -> $boolean
Move a row
   * =$from= 0-based index of the row to move
   * =$to= 0-based index of the target position (before =$from= is removed!)
   * =$any_row= - true to request moving of header and footer rows
Rows must exist. The rows must be editable rows unless =$any_row= is true.

If =$any_row= is false, the table will be made consistent (missing
header/footer rows added) before anything else is done.

If $to is outside the editable part of the table, the row will be moved
to the first or last editable position respectively.

Returns true if the move succeeded.

=cut

sub moveRow {
    my ( $this, $from, $to, $any_row ) = @_;

    $this->makeConsistent() unless $any_row;

    return 0 if $to == $from;
    return 0
      unless $this->isEditableRow($from)
      || $any_row && $from >= 0 && $from < $this->totalRows();
    unless ($any_row) {
        $to = $this->getHeaderRows()      if $to < $this->getHeaderRows();
        $to = $this->getLastBodyRow() + 1 if $to > $this->getLastBodyRow();
    }

    my @moving = splice( @{ $this->{rows} }, $from, 1 );

    # compensate for row just removed
    my $rto = ( $to > $from ) ? $to - 1 : $to;

    if ( $rto >= $this->totalRows() ) {
        push( @{ $this->{rows} }, @moving );
    }
    else {
        splice( @{ $this->{rows} }, $rto, 0, @moving );
    }
    $this->_renumber();
    return 1;
}

=begin TML

---++ ObjectMethod upRow($row [, $any_row]) -> $boolean
Move a row up one position in the table
   * =$row= 0-based index of the row to move
    * =$any_row= - true to request moving of header and footer rows
Row must exist. The row must be editable row unless =$any_row= is true.

If =$any_row= is false, the table will be made consistent (missing
header/footer rows added) before anything else is done.

Returns 1 if the move succeeded.

=cut

sub upRow {
    my ( $this, $row, $any_row ) = @_;

    $this->makeConsistent() unless $any_row;

    return 0
      unless $this->isEditableRow($row)
      || $any_row && $row >= 0 && $row < $this->totalRows();
    my $tmp = $this->{rows}->[$row];
    $this->{rows}->[$row] = $this->{rows}->[ $row - 1 ];
    $this->{rows}->[ $row - 1 ] = $tmp;
    $this->_renumber( $row - 1 );
    return 1;
}

=begin TML

---++ ObjectMethod downRow($row [, $any_row]) -> $boolean
Move a row down one position in the table
   * =$row= 0-based index of the row to move
    * =$any_row= - true to request moving of header and footer rows
Row must exist. The row must be editable row unless =$any_row= is true.

If =$any_row= is false, the table will be made consistent (missing
header/footer rows added) before anything else is done.

Returns 1 if the move succeeded.

=cut

sub downRow {
    my ( $this, $row, $any_row ) = @_;

    $this->makeConsistent() unless $any_row;

    return 0
      unless $this->isEditableRow($row)
      || $any_row && $row >= 0 && $row < $this->totalRows();
    my $tmp = $this->{rows}->[$row];
    $this->{rows}->[$row] = $this->{rows}->[ $row + 1 ];
    $this->{rows}->[ $row + 1 ] = $tmp;
    $this->_renumber($row);
    return 1;
}

# PROTECTED method that parses a column type specification
sub parseFormat {
    my ( $this, $format ) = @_;
    my @cols;

    $format =~ s/^\s*\|//;
    $format =~ s/\|\s*$//;

    $format =~ s/\$nop(\(\))?//gs;
    $format =~ s/\$quot(\(\))?/\"/gs;
    $format =~ s/\$percnt(\(\))?/\%/gs;
    $format =~ s/\$dollar(\(\))?/\$/gs;
    $format =~ s/<nop>//gos;

    foreach my $column ( split( /\|/, $format ) ) {
        my ( $type, $size, @values ) = split( /,/, $column );

        $type ||= 'text';
        $type = lc $type;
        $type =~ s/^\s*//;
        $type =~ s/\s*$//;

        $size ||= 0;
        $size =~ s/[^\w.]//g;

        unless ($size) {
            if ( $type eq 'text' ) {
                $size = 20;
            }
            elsif ( $type eq 'textarea' ) {
                $size = '40x5';
            }
            else {
                $size = 1;
            }
        }

        my $initial;
        if ( $type =~ /^(text|label)/ ) {
            $initial = join( ',', @values );
        }
        elsif ( $type eq 'date' ) {
            $initial = shift @values;
        }
        elsif ( $type =~ /^(radio|select|checkbox)/ && scalar(@values) ) {
            $initial = $values[0];
        }
        $initial = '' unless defined $initial;

        @values = map { s/^\s*//; s/\s*$//; $_ } @values;
        push(
            @cols,
            {
                type          => $type,
                size          => $size,
                values        => \@values,
                initial_value => $initial,
            }
        );
    }
    return \@cols;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2009-2014 Foswiki Contributors
Portions Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.

All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.


