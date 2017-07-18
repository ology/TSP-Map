package TSP::Map;

use Dancer2;
use Algorithm::TravelingSalesman::BitonicTour;
use Math::Geometry::Planar;
use HTML::GoogleMaps::V3;
use Geo::Coder::OSM;

our $VERSION = '0.1';

any '/' => sub {
    my $coordinates = request->upload('coordinates');
    my $addresses   = request->upload('addresses');

    my ( $link, $path );

    if ($coordinates) {
        ( $link, $path ) = process_coordinates($coordinates);
    }
    elsif ($addresses) {
        ( $link, $path ) = process_addresses($addresses);
    }

    template 'index' => {
        title => 'Traveling Salesperson',
        link  => $link,
        path  => $path,
    };
};

sub process_coordinates {
    my ($coordinates) = @_;

    my $coord_name;

    my $tsp = Algorithm::TravelingSalesman::BitonicTour->new;

    my $content = $coordinates->content;

    my @lines = split /\n/, $content;

    for my $line (@lines) {
        my @place = split /\s*,\s*/, $line;
        my @point = @place[ 0 .. 1 ];
        $tsp->add_point(@point);
        $coord_name->{ join ',', @point } = $place[2];
    }

    my ( undef, @coords ) = $tsp->solve;

    my ( $link, $path ) = build_map( $coord_name, @coords );

    return $link, $path;
}

sub process_addresses {
    my ($addresses) = @_;

    my $coord_name;

    my $tsp = Algorithm::TravelingSalesman::BitonicTour->new;

    my $geocoder = Geo::Coder::OSM->new;

    my $content = $addresses->content;

    my @lines = split /\n/, $content;

    for my $line (@lines) {
        my $location = $geocoder->geocode( location => $line );
        my @point = ( $location->{lon}, $location->{lat} );
        $tsp->add_point(@point);
        $coord_name->{ join ',', @point } = $line;
    }

    my ( undef, @coords ) = $tsp->solve;

    my ( $link, $path ) = build_map( $coord_name, @coords );

    return $link, $path;
}

sub build_map {
    my ( $coord_name, @coords ) = @_;

    my ( $link, $path );

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

        $path .= sprintf "%d. %s [%s]<br/>\n", $i, $coord_name->{$key}, $key
            unless $i == @coords;
    }

    $link = qq|<a href="$multi">Route Driving Directions</a>|;

    $map->add_polyline( points => [ @coords[ 0 .. $#coords - 1 ] ] );

    my ( $head, $map_div ) = $map->onload_render;

    open( my $fh, ">", 'public/map.html' ) or die "Can't write public/map.html: $!";
    print $fh qq|<html><head><title>Test</title>$head</head>|;
    print $fh qq|<body onload="html_googlemaps_initialize()">$map_div</body></html>|;
    close $fh;

    return $link, $path;
}

true;
