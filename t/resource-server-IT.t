#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More;
use Test::MockModule;
use HTTP::Request::Common;

use FindBin qw($Bin);
use lib "$Bin/resource-server-IT/MyCatalystApp/lib";

local $ENV{MOJO_LOG_LEVEL} = 'error';

my $provider_app = require "$Bin/resource-server-IT/MyProviderApp/app.pl";

my $mock_oidc_client = Test::MockModule->new('OIDC::Client');
$mock_oidc_client->redefine('user_agent' => $provider_app->ua);
$mock_oidc_client->redefine('decode_jwt' => sub {
  my %params = @_;
  if ($params{token} eq 'Doe') {
    return {
      iss       => 'my_issuer',
      exp       => 12345,
      aud       => 'my_id',
      sub       => 'DOEJ',
      firstName => 'John',
      lastName  => 'Doe',
      roles     => [qw/app.role1 app.role2/],
    }
  }
  elsif ($params{token} eq 'Smith') {
    return {
      iss       => 'my_issuer',
      exp       => 12345,
      aud       => 'my_id',
      sub       => 'SMITHL',
      firstName => 'Liam',
      lastName  => 'Smith',
      roles     => [qw/app.role3/],
    }
  }
  else {
    die 'invalid token';
  }
});

require Catalyst::Test;
Catalyst::Test->import('MyCatalystApp');

subtest 'Get resource - unknown user' => sub {
  my $res = request(GET '/my-resource',
                    Authorization => 'Bearer Unknown');
  is($res->code, 401, 'Expected error code');
  is($res->content, '{"error":"Unauthorized"}', 'Expected response content');
};

subtest 'Get resource - user with insufficient roles' => sub {
  my $res = request(GET '/my-resource',
                    Authorization => 'Bearer Smith');
  is($res->code, 403, 'Expected error code');
  is($res->content, '{"error":"Forbidden"}', 'Expected response content');
};

subtest 'Get resource - known user with sufficient roles' => sub {
  my $res = request(GET '/my-resource',
                    Authorization => 'Bearer Doe');
  is($res->code, 200, 'Expected code');
  is($res->content, '{"user_login":"DOEJ"}', 'Expected response content');
};

done_testing;
