package openAIChatPlugin::OpenAIClient;

use JSON;
use openAIChatPlugin::OpenAIClient;

sub new {
    my ($class, %args) = @_;
    my $self = {
        api_key  => $args{api_key},
        model    => $args{model} || 'gpt-3.5-turbo',
        endpoint => $args{endpoint} || 'https://api.openai.com/v1/chat/completions',
    };
    bless $self, $class;
    return $self;
}

sub sendRequest {
    my ($self, $prompt, $chatLog) = @_;

    my $ua = LWP::UserAgent->new;
    my $headers = HTTP::Headers->new('Content-Type' => 'application/json');

    my @messages = (
        { role => 'system', content => $prompt },
    );

    for my $line (split /\n/, $chatLog) {
        if ($line =~ /^\[(\d+)\] (.*?): (.*)$/) {
            my ($timestamp, $sender, $message) = ($1, $2, $3);
            push @messages, { role => lc($sender) eq 'ai' ? 'assistant' : 'user', content => $message };
        }
    }

    Log::message "Sending request to OpenAI API with messages: " . encode_json(\@messages), "OpenAIChatPlugin";

    my $json_data = encode_json({
        model    => $self->{model},
        messages => \@messages,
    });

    my $req = HTTP::Request->new(
        'POST',
        $self->{endpoint},
        $headers,
        $json_data
    );
    $req->header('Authorization' => "Bearer $self->{api_key}");

    Log::message "Sending request to $self->{endpoint}\n", "OpenAIChatPlugin";

    my $response = $ua->request($req);
    if ($response->is_success) {
        my $data = decode_json($response->content);
        Log::message "Received response from OpenAI API: " . $data->{choices}[0]{message}{content}, "OpenAIChatPlugin";
        return $data->{choices}[0]{message}{content};
    } else {
        Log::error "Error from OpenAI API: " . $response->status_line, "OpenAIChatPlugin";
        return "Error: " . $response->status_line;
    }
}

1;
