package TSP::Map;

use Dancer2;
use Algorithm::TravelingSalesman::BitonicTour;
use Math::Geometry::Planar;
use HTML::GoogleMaps::V3;

our $VERSION = '0.1';

any '/' => sub {
    my $upload = request->upload('fileToUpload');
    my $content;
    my $out;
    my $path;

    if ($upload) {
        my $coord_name;

        my $tsp = Algorithm::TravelingSalesman::BitonicTour->new;

        $content = $upload->content;

        my @lines = split /\n/, $content;

        for my $line (@lines) {
            my @place = split /\s*,\s*/, $line;
            my @point = @place[ 0 .. 1 ];
            $tsp->add_point(@point);
            $coord_name->{ join ',', @point } = $place[2];
        }

        my ( undef, @coords ) = $tsp->solve;

        my $polygon = Math::Geometry::Planar->new;
        $polygon->points( [ @coords[ 1 .. $#coords ] ] );
        my $centroid = $polygon->centroid;

        my $map = HTML::GoogleMaps::V3->new( height => 800, width => 800 );
        $map->zoom(12);
        $map->center($centroid);

        my $base  = 'https://www.google.com/maps/dir';
        my $multi = $base;  # Multiple point path accumulator

        my $i = 0;

        for my $coord (@coords) {
            my $point = join ',', $coord->[1], $coord->[0];  # Google maps wants lat/lon

            $multi .= "/$point" unless $i == @coords - 1;

            my $key = join ',', @$coord;
            $coord_name->{$key} =~ s/'/`/g;  # Single quotes conflict with the marker

            $map->add_marker(
                point => $coord,
                html  => qq|<div id="content"><h3 id="firstHeading" class="firstHeading">$coord_name->{$key}</h3><a href="$base/$point">Directions to here</a></div>|,
            );

            $i++;

            $path .= sprintf "%d. %s [%s]<br/>\n", $i, $coord_name->{$key}, $key;
        }

        $out = qq|<a href="$multi">Route Driving Directions</a>|;

        $map->add_polyline( points => [ @coords[ 0 .. $#coords - 1 ] ] );

        my ( $head, $map_div ) = $map->onload_render;

        open( my $fh, ">", 'public/map.html' ) or die "Can't write public/map.html: $!";
        print $fh qq|<html><head><title>Test</title>$head</head>|;
        print $fh qq|<body onload="html_googlemaps_initialize()">$map_div</body></html>|;
        close $fh;
    }

    template 'index' => {
        title   => 'Traveling Salesperson',
        content => $out,
        path    => $path,
    };
};

true;
