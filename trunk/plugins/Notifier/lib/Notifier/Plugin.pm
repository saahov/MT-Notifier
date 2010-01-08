# ===========================================================================
# A Movable Type plugin with subscription options for your installation
# Copyright 2003-2009 Everitz Consulting <everitz.com>.
#
# This program is free software:  You may redistribute it and/or modify it
# it under the terms of the Artistic License version 2 as published by the
# Open Source Initiative.
#
# This program is distributed in the hope that it will be useful but does
# NOT INCLUDE ANY WARRANTY; Without even the implied warranty of FITNESS
# FOR A PARTICULAR PURPOSE.
#
# You should have received a copy of the Artistic License with this program.
# If not, see <http://www.opensource.org/licenses/artistic-license-2.0.php>.
# ===========================================================================
package Notifier::Plugin;

use strict;

use MT;

# callbacks

sub check_comment {
  my ($err, $obj) = @_;
  my $id = 'blog:'.$obj->blog_id;
  my $notify = 1;
  $notify = 0 unless ($obj->visible);
  my $plugin = MT::Plugin::Notifier->instance;
  $notify = 0 if ($plugin->get_config_value('blog_disabled', $id));
  require MT::Request;
  my $r = MT::Request->instance;
  $r->cache('mtn_notify_comment_'.$id, $notify);
}

sub check_entry {
  my ($err, $obj) = @_;
  my $plugin = MT::Plugin::Notifier->instance;
  return if ($plugin->get_config_value('blog_disabled', 'blog:'.$obj->blog_id));
  require MT::Entry;
  if ($obj->status == MT::Entry::RELEASE()) {
    if (my $notify = $obj->id) {
      require MT::Request;
      my $r = MT::Request->instance;
      $r->cache('mtn_notify_entry', $notify);
    }
  }
}

sub notify_comment {
  my ($err, $obj) = @_;
  my $id = 'blog:'.$obj->blog_id;
  if ($obj->is_not_junk) {
    require Notifier::Data;
    if (MT->app->param('subscribe')) {
      require Notifier;
      Notifier::create_subscription($obj->email, Notifier::Data::SUBSCRIBE(), 0, 0, $obj->entry_id)
    }
    require MT::Request;
    my $r = MT::Request->instance;
    return unless ($r->cache('mtn_notify_comment_'.$id));
    my @work_subs =
      map { $_ }
      Notifier::Data->load({
        blog_id => $obj->blog_id,
        entry_id => $obj->entry_id,
        record => Notifier::Data::SUBSCRIBE(),
        status => Notifier::Data::RUNNING()
      });
    my $plugin = MT::Plugin::Notifier->instance;
    if ($plugin->get_config_value('blog_all_comments', $id)) {
      my @blog_subs =
        map { $_ }
        Notifier::Data->load({
            blog_id => $obj->blog_id,
            record => Notifier::Data::SUBSCRIBE(),
            status => Notifier::Data::RUNNING()
        });
      push @work_subs, @blog_subs;
      foreach my $c ($obj->entry->categories) {
        require MT::Category;
        my $cat = MT::Category->load($c);
        next unless (ref $cat);
        my @cat_subs =
          map { $_ }
          Notifier::Data->load({
            cat_id => $cat->id,
            record => Notifier::Data::SUBSCRIBE(),
            status => Notifier::Data::RUNNING()
          });
        push @work_subs, @cat_subs;
      }
    }
    my $work_users = scalar @work_subs;
    return unless ($work_users);
    Notifier::notify_users($obj, \@work_subs);
  }
}

sub notify_entry {
  my ($err, $obj) = @_;
  require MT::Request;
  my $r = MT::Request->instance;
  my $notify = $r->cache('mtn_notify_entry');
  return unless ($notify);
  require Notifier;
  Notifier::entry_notifications($notify);
}

# template tags

sub notifier_category_id {
  my ($ctx, $args) = @_;
  my $cat_id = '';
  if (my $cat = $ctx->stash('category') || $ctx->stash('archive_category')) {
    $cat_id = $cat->id;
  } elsif (my $entry = $ctx->stash('entry')) {
    require MT::Placement;
    my $placement = MT::Placement->load({
      entry_id => $entry->id,
      is_primary => 1
    });
    $cat_id = $placement->category_id if $placement;
  }
  $cat_id;
}

sub notifier_check {
  return MT->app->param('subscribe');
}

# plugin registration

sub list_actions {
  my $app = MT->app;
  return {
    'blog' => {
      'mtn_add_subscription' => {
        label      => q(<MT_TRANS phrase="Add Subscription(s)">),
        order      => 1000,
        code       => '$Notifier::Notifier::App::_ui_sub',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ) ? 1 : 0;
        }
      },
      'mtn_add_subscription_block' => {
        label      => q(<MT_TRANS phrase="Add Subscription Block(s)">),
        order      => 1100,
        code       => '$Notifier::Notifier::App::_ui_opt',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ) ? 1 : 0;
        }
      },
      'mtn_view_subscription_count' => {
        label      => q(<MT_TRANS phrase="View Subscription Count(s)">),
        order      => 1200,
        code       => '$Notifier::Notifier::App::_ui_vue',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ) ? 1 : 0;
        }
      },
      'mtn_write_history_records' => {
        label      => q(<MT_TRANS phrase="Write History Records">),
        order      => 1400,
        code       => '$Notifier::Notifier::App::_sub_history',
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ) ? 1 : 0;
        }
      },
    },
    'category' => {
      'mtn_add_subscription' => {
        label      => q(<MT_TRANS phrase="Add Subscription(s)">),
        order      => 1000,
        code       => '$Notifier::Notifier::App::_ui_sub',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
      'mtn_add_subscription_block' => {
        label      => q(<MT_TRANS phrase="Add Subscription Block(s)">),
        order      => 1100,
        code       => '$Notifier::Notifier::App::_ui_opt',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
      'mtn_view_subscription_count' => {
        label      => q(<MT_TRANS phrase="View Subscription Count(s)">),
        order      => 1200,
        code       => '$Notifier::Notifier::App::_ui_vue',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
    },
    'entry' => {
      'mtn_add_subscription' => {
        label      => q(<MT_TRANS phrase="Add Subscription(s)">),
        order      => 1000,
        code       => '$Notifier::Notifier::App::_ui_sub',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
      'mtn_add_subscription_block' => {
        label      => q(<MT_TRANS phrase="Add Subscription Block(s)">),
        order      => 1100,
        code       => '$Notifier::Notifier::App::_ui_opt',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
      'mtn_view_subscription_count' => {
        label      => q(<MT_TRANS phrase="View Subscription Count(s)">),
        order      => 1200,
        code       => '$Notifier::Notifier::App::_ui_vue',
        dialog     => 1,
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
    },
    'subscription' => {
      'mtn_block_subscription' => {
        label      => q(<MT_TRANS phrase="Block Subscription(s)">),
        order      => 100,
        code       => '$Notifier::Notifier::App::_sub_block',
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
      'mtn_clear_subscription' => {
        label      => q(<MT_TRANS phrase="Clear Subscription Block(s)">),
        order      => 200,
        code       => '$Notifier::Notifier::App::_sub_clear',
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
      'mtn_verify_subscription' => {
        label      => q(<MT_TRANS phrase="Verify Subscription(s)">),
        order      => 300,
        code       => '$Notifier::Notifier::App::_sub_verify',
        condition  => sub {
          return 0 if $app->mode eq 'view';
          return ( $app->user->is_superuser() ||
                   $app->permissions->can_administer_blog ||
                   $app->permissions->can_edit_notifications ) ? 1 : 0;
        }
      },
    },
  }
}

sub methods {
  my $app = MT->instance->app;
  return {
    block_subs  => {
      code           => '$Notifier::Notifier::App::block_subs',
      requires_login => 1,
    },
    clear_subs  => {
      code           => '$Notifier::Notifier::App::clear_subs',
      requires_login => 1,
    },
#    clone_subs  => {
#      code           => '$Notifier::Notifier::App::clone_subs',
#      requires_login => 1,
#    },
    create_subs => {
      code           => '$Notifier::Notifier::App::create_subs',
      requires_login => 1,
    },
#    import_subs  => {
#      code           => '$Notifier::Notifier::App::import_subs',
#      requires_login => 1,
#    },
#    queued_subs => {
#      code           => '$Notifier::Notifier::App::queued_subs',
#      requires_login => 1,
#    },
    verify_subs => {
      code           => '$Notifier::Notifier::App::verify_subs',
      requires_login => $app->param('return_args') ? 1 : 0,
    },
    widget_sub_blog => {
      code           => '$Notifier::Notifier::App::_widget_blog',
      requires_login => 1,
    },
    widget_sub_category => {
      code           => '$Notifier::Notifier::App::_widget_category',
      requires_login => 1,
    },
    widget_sub_entry => {
      code           => '$Notifier::Notifier::App::_widget_entry',
      requires_login => 1,
    },
  }
}

1;