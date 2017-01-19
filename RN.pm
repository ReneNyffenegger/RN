# vim: foldmarker={{{,}}} foldmethod=marker
package RN;

use warnings;
use strict;

use File::Path qw(make_path);
use File::Basename;
use File::Copy;

use lib "$ENV{github_top_root}lib/tq84-PerlModules";
use tq84_ftp;

our $target_env; # local, test or web

my $ftp;

my %fh_to_url_path_abs;

my $verbose;

sub init { # {{{
  $target_env = shift;
  $verbose    = shift;

  die "Unknown target_env $target_env" unless $target_env eq 'local' or $target_env eq 'test' or $target_env eq 'web';

  print "RN: target_env=$target_env\n" if $verbose >= 1;

  if ($target_env eq 'web') {
    $ftp = new tq84_ftp('TQ84_RN');
  }
} # }}}

sub url_path_abs_2_os_path_abs { # {{{

  my $url_path_abs = shift;

  return  "$ENV{rn_root}${target_env}$url_path_abs";

} # }}}

sub url_path_abs_2_url_full { # {{{
  my $url_path_abs = shift;


  if ($target_env eq 'web' or $target_env eq 'test') {
    return $url_path_abs;
  }

  if ($target_env eq 'local') {
    my $url_full =  "file://" . url_path_abs_2_os_path_abs($url_path_abs);
    $url_full =~ s,\\,/,g;
    return $url_full;
  }

  die "Unknown target_env $target_env";

} # }}}

sub ensure_dir_for_url_path_abs { # {{{

  my $url_path_abs = shift;

  die "Unknown target_env $target_env" unless $target_env eq 'local' or $target_env eq 'test' or $target_env eq 'web';

  if ($target_env eq 'web') {

    my $dir = "/httpdocs" . dirname($url_path_abs);

    if ($ftp->isfile($dir)) {
      print "! ftp ensure_dir_for_url_path_abs, $dir is a file\n";
    }

    $ftp -> mkdir($dir, 1); # or die "Could not create directory $dir";
  }

  my $os_path_abs = url_path_abs_2_os_path_abs($url_path_abs);
  my $os_dir      = dirname($os_path_abs);

  unless (-d $os_dir) {
    if (-e $os_dir) {
    # 2016-12-18
      unlink $os_dir or die "Could not unlink $os_dir";
    }
    make_path($os_dir) or die "Could not make_path($os_dir)";
  }

} # }}}

sub open_url_path_abs { # {{{

  my $url_path_abs = shift;

  die "Unknown target_env $target_env" unless $target_env eq 'local' or $target_env eq 'test' or $target_env eq 'web';

  ensure_dir_for_url_path_abs($url_path_abs);

  my $os_path_abs = url_path_abs_2_os_path_abs($url_path_abs);

  open (my $out, '>:encoding(UTF-8)', $os_path_abs) or print "! RN::open_url_path_abs Could not open $os_path_abs\n" ;

  $fh_to_url_path_abs{$out} = $url_path_abs;

  print "RN.pm open_url_path_abs returning\n" if $verbose;
  return $out;
} # }}}

sub close_ { # {{{

  my $fh = shift;

  die "fh not found in fh_to_url_path_abs" unless exists $fh_to_url_path_abs{$fh};

  my $url_path_abs = $fh_to_url_path_abs{$fh};
  delete $fh_to_url_path_abs{$fh};

  close $fh;

  if ($target_env eq 'local' or $target_env eq 'test') {
    return;
  }

  die "Unknown target_env $target_env" unless $target_env eq 'web';

  my $os_path_abs = url_path_abs_2_os_path_abs($url_path_abs);

  RN::copy_os_path_2_url_path_abs($os_path_abs, $url_path_abs);

} # }}}

sub copy_os_path_2_url_path_abs { # {{{

  my $os_path_src       = shift; # can be relativ or absolute
  my $url_path_dest_abs = shift;

  die "$os_path_src does not exist" unless -e $os_path_src;

  if ($target_env eq 'web') {
    my $dir  =  "/httpdocs" . dirname($url_path_dest_abs);

    if ($ftp->isfile($dir)) {
      print "! ftp $dir is a file, should be a directory\n";
    }
    if (! $ftp->isdir($dir)) {
      print "! ftp $dir is not a directory, creating...\n";
      $ftp -> mkdir($dir, 1);
    }

    $ftp->cwd($dir) or print "! ftp could not cwd to $dir\n";

#
#   2017-01-09 Swisscom … why oh why ?
#   $ftp->put($os_path_src) or print "! ftp could not put $os_path_src, ftp pwd=" . $ftp->pwd() . "\n";
#
    my $put_successful = 0;
    print "RN.pm Trying to ftp-rm $os_path_src, ftp pwd=" . $ftp->pwd() . "\n" if $verbose;
    while (! $put_successful) {
        eval {
            local $SIG{ALRM} = sub { die "ftp-put-timeout" };
            print "RN.pm Trying to put $os_path_src, ftp pwd=" . $ftp->pwd() . "\n" if $verbose;
            alarm 5;
            $put_successful = $ftp->put($os_path_src);
            alarm 0;
            print "RN.pm           put $os_path_src\n" if $verbose;
        };
        if ($@) { # timed out
            die "other error >$!< in ftp put timeout, \$\@ = >$@<" unless $@ =~/^ftp-put-timeout/;   # propagate unexpected errors
            print "ftp put timed out, redo $os_path_src, ftp->pwd=" . $ftp->pwd() . "\n";
            $ftp = new tq84_ftp('TQ84_RN');
            $ftp->cwd($dir);
        }

    }

  }
  elsif ($target_env eq 'test' or $target_env eq 'local') {

    my $os_path_dest_abs = url_path_abs_2_os_path_abs($url_path_dest_abs);

    ensure_dir_for_url_path_abs($url_path_dest_abs);

    copy($os_path_src, $os_path_dest_abs) or die "Could not copy $os_path_src to $os_path_dest_abs";

  }
  else {
    die "Unknown target_env $target_env";
  }

} # }}}

sub copy_url_path_abs_2_os_path { # {{{

  my $url_path_src_abs = shift;
  my $os_path_dest     = shift; # can be relativ or absolute


  if ($target_env eq 'web') {
    $ftp->get("/httpdocs$url_path_src_abs", $os_path_dest) or print "! ftp could not get $url_path_src_abs\n";
  }
  elsif ($target_env eq 'test' or $target_env eq 'local') {

    die "Implement me";

  }
  else {
    die "Unknown target_env $target_env";
  }

} # }}}

1;
