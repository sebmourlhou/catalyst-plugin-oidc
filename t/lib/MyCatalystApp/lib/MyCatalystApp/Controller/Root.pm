package MyCatalystApp::Controller::Root;
use utf8;
use Moose;
use namespace::autoclean;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body( $c->welcome_message );
}

sub protected : Global {
  my ( $self, $c ) = @_;

  if (my $identity = $c->oidc->get_stored_identity()) {
      $c->response->body($identity->{subject} . ' is authenticated');
  }
  else {
      $c->oidc->redirect_to_authorize();
  }
}

sub error : Chained('/') : PathPart('error') : Args(1) {
    my ( $self, $c, $http_code ) = @_;
    $c->log->warn("OIDC error : " . $c->flash->{error_message});
    $c->response->body( 'Authentication Error' );
    $c->response->status($http_code);
}

# ----------------------
# resource server routes
# ----------------------
sub my_resource :Path('my-resource') :Args(0) {
  my ( $self, $c ) = @_;

  my $user = try {
    $c->oidc->verify_token();
    return $c->oidc->build_user_from_userinfo();
  }
  catch {
    $c->log->warn("Token/User validation : $_");
    $c->stash->{expose_stash}{error} = 'Unauthorized';
    $c->forward('View::JSON');
    $c->response->status(401);
    return;
  } or return;

  unless ($user->has_role('role2')) {
    $c->log->warn("Insufficient roles");
    $c->stash->{expose_stash}{error} = 'Forbidden';
    $c->forward('View::JSON');
    $c->response->status(403);
    return;
  }

  $c->stash->{expose_stash}{user_login} = $user->login;
  $c->forward('View::JSON');
}

# ----------------------
# provider server routes
# ----------------------
sub authorize : Global {
    my ( $self, $c ) = @_;

    my $redirect_uri  = $c->req->param('redirect_uri');
    my $client_id     = $c->req->param('client_id');
    my $state         = $c->req->param('state');
    my $response_type = $c->req->param('response_type');
    if ($response_type eq 'code' && $client_id eq 'my_id') {
        $c->response->redirect("$redirect_uri?client_id=$client_id&state=$state&code=abc&iss=my_issuer");
    }
    else {
        $c->response->redirect("$redirect_uri?error=error");
    }
}
# ----------------------

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->meta->make_immutable;

1;
