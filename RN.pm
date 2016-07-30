package RN;

use warnings;
use strict;

use File::Path qw(make_path);
use File::Basename;
use File::Copy;

my $target_env; # local, test or web

sub init {
  $target_env = shift;
  die "Unknown target_env $target_env" unless $target_env eq 'local' or $target_env eq 'test' or $target_env eq 'web';
}

sub url_path_abs_2_os_path_abs { # {{{

  my $url_path_abs = shift;

  return  "$ENV{rn_root}${target_env}$url_path_abs";

} # }}}

sub url_path_abs_2_url_full { # {{{
  my $url_path_abs = shift;


  if ($target_env eq 'prod' or $target_env eq 'test') {
    return "http://renenyffenegger.ch$url_path_abs";
  }

  if ($target_env eq 'local') {
    return "file://" . url_path_abs_2_os_path_abs($url_path_abs);
  }

  die "Unknown target_env $target_env";

} # }}}

sub ensure_dir_for_url_path_abs { # {{{

  my $url_path_abs = shift;


  if ($target_env eq 'web') {
    die "Implement me"
  }
  elsif ($target_env eq 'local' or $target_env eq 'test') {

    my $os_path_abs = url_path_abs_2_os_path_abs($url_path_abs);
    my $os_dir      = dirname($os_path_abs);

    unless (-d $os_dir) {
      make_path($os_dir) or die "Could not make_path($os_dir)";
    }
  }
  else {
    die "Unknown target_env $target_env";
  }

} # }}}

sub open_url_path_abs { # {{{

  my $url_path_abs = shift;

  die "Unknown target_env $target_env" unless $target_env eq 'local' or $target_env eq 'test' or $target_env eq 'web';

  ensure_dir_for_url_path_abs($url_path_abs);

  my $os_path_abs = url_path_abs_2_os_path_abs($url_path_abs);

  open (my $out, '>:encoding(UTF-8)', $os_path_abs) or die "\nCould not open $os_path_abs" ;

  return $out;
} # }}}

sub copy_os_path_2_url_path_abs {

  my $os_path_src       = shift; # can be relativ or absolute
  my $url_path_dest_abs = shift;

  die "$os_path_src does not exist" unless -e $os_path_src;

  if ($target_env eq 'prod') {
     die "Implement me";
  }
  elsif ($target_env eq 'test' or $target_env eq 'local') {

    my $os_path_dest_abs = url_path_abs_2_os_path_abs($url_path_dest_abs);

    ensure_dir_for_url_path_abs($url_path_dest_abs);

    copy($os_path_src, $os_path_dest_abs) or die "Could not copy $os_path_src to $os_path_dest_abs";

  }
  else {
    die "Unknown target_env $target_env";
  }

}

1;
