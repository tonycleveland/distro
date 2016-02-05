# tests for the correct expansion of NOP

package Fn_NOP;
use v5.14;

use Foswiki;
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

around BUILDARGS => sub {
    my $orig = shift;
    return $orig->( @_, testSuite => 'NOP' );
};

sub test_NOP {
    my $this = shift;
    my ($topicObject) = Foswiki::Func::readTopic( $this->test_web, 'WebHome' );
    my $result = $topicObject->expandMacros("%NOP%");
    $this->assert_equals( '<nop>', $result );

    $result = $topicObject->expandMacros("%NOP{   ignore me   }%");
    $this->assert_equals( "   ignore me   ", $result );

    $result = $topicObject->expandMacros("%NOP{%SWINE%}%");
    $this->assert_equals( "%SWINE%", $result );

    $result = $topicObject->expandMacros("%NOP{%WEB%}%");
    $this->assert_equals( $this->test_web, $result );

    $result = $topicObject->expandMacros("%NOP{%WEB{}%}%");
    $this->assert_equals( $this->test_web, $result );

    $topicObject->text("%NOP%");
    $topicObject->expandNewTopic();
    $result = $topicObject->text();

    $this->assert_equals( '', $result );

    $topicObject->text("%GM%NOP%TIME%");
    $topicObject->expandNewTopic();
    $result = $topicObject->text();

    $this->assert_equals( '%GMTIME%', $result );

    $topicObject->text("%NOP{   ignore me   }%");
    $result = $topicObject->expandNewTopic();
    $result = $topicObject->text();
    $this->assert_equals( '', $result );

    # this *ought* to work, but by the definition of TML, it doesn't.
    #$result = $topicObject->expandMacros("%NOP{%FLEEB{}%}%");
    #$this->assert_equals("%FLEEB{}%", $result);
}

1;
