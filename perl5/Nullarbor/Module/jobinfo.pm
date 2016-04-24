package Nullarbor::Module::jobinfo;
use Moo;
extends 'Nullarbor::Module';

use Sys::Hostname;

#...........................................................................................

sub name {
  return "Report summary";
}

#...........................................................................................

sub tt {
  return "<tt>@_</tt>";
}

#...........................................................................................

sub html {
  my($self) = @_;
  
  my $meta_data = [
    [ "Isolates", "Author", "Date", "Host", "Folder" ],
    [ 
      scalar(@{$self->isolates}), 
      tt( $ENV{USER} || $ENV{LOGNAME} || 'anonymous' ),
      scalar(localtime(time)),
      tt ( hostname ),
      tt( $self->indir ),
    ],
  ];
  return $self->matrix_to_html($meta_data, 1);   # 0 = no fancy sorting
}

#...........................................................................................

1;

