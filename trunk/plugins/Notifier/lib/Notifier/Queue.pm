# ===========================================================================
# Copyright Everitz Consulting.  Not for redistribution.
# ===========================================================================
package Notifier::Queue;

use strict;

use MT::Object;
@Notifier::Queue::ISA = qw(MT::Object);
__PACKAGE__->install_properties({
    column_defs => {
        'id' => 'integer not null auto_increment',
        'head_content' => 'string(75)',
        'head_from' => 'string(75) not null',
        'head_to' => 'string(75) not null',
        'head_subject' => 'text',
        'body' => 'text',
    },
    datasource => 'notifier_queue',
    primary_key => 'id',
});

1;
