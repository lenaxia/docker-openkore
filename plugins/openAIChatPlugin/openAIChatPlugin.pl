package openAIChatPlugin;

use lib $Plugins::current_plugin_folder;

use strict;
use Plugins;
use Globals qw(%config $messageSender $char %players $field);
use Commands;
use Log qw(message warning error);
use Misc qw(sendMessage);
use LWP::UserAgent;
use JSON;

use openAIChatPlugin::OpenAIClient

# Register the plugin
Plugins::register("openAIChatPlugin", "OpenAI Chat Plugin", \&unload);

our $messageSender = $::messageSender;

# OpenAI API client
my $openAIClient;
eval {
    $openAIClient = openAIChatPlugin::OpenAIClient->new(
        api_key  => $config{OpenAIChatPlugin_apiKey} || "",
        model    => $config{OpenAIChatPlugin_model} || "bedrock-claude-v2-sonnet",
        endpoint => $config{OpenAIChatPlugin_endpoint} || "http://192.168.5.72:4000/v1/chat/completions"
    );
};
if ($@) {
    Log::error "Error initializing OpenAI API client: $@";
    return;
}

# Chat log (up to 100 lines)
my @chatLog = ();
my $maxChatLogLines = 100;

# Prompt for the OpenAI API
my $prompt = $config{OpenAIChatPlugin_prompt} || "You are a merchant named Lenaxia in the MMORPG ragnarok online, you are friendly and independent, you have a business streak and an eye for making money. Fully embody the character. Please review the chat log and determine if you are in a conversation, if the most recent message is directed at you, respond to it, if not, do not respond. Keep your response <60 characters, single line, as if you're chatting with friends. If someone says hi, greet them as a normal person would, do NOT respond like an LLM assistant. Here is raw information about yourself and world state: $char, %players, $field";

# Hooks for different chat channels
my %chatHooks;

sub handleChatMessage {
    my ($packet, $args) = @_;

    my $sender = $args->{privMsgUser} || $args->{pubMsgUser} || "System";
    my $message = ($args->{privMsg} || $args->{pubMsg}) || return;

    # Log the incoming message
    Log::message "Received message from $sender: $message\n", "OpenAIChatPlugin";

    # Add the message to the chat log
    my $timestamp = time();
    push @chatLog, "[$timestamp] $sender: $message";
    shift @chatLog if scalar(@chatLog) > $maxChatLogLines;

    # Check if the message is a command for the plugin
    if ($message =~ /^\/ai (.+)/) {
        my $query = $1;
        my $chatContext = join("\n", @chatLog);
        Log::message "Processing query: $query", "OpenAIChatPlugin";

        my $response;
        eval {
            $response = $openAIClient->sendRequest($prompt, $chatContext);
        };
        if ($@) {
            Log::error "Error sending request to OpenAI API: $@", "OpenAIChatPlugin";
            sendChatResponse("Error: $@", $args->{privMsgUser} ? 'priv' : 'pub', $args);
            return;
        }

        Log::message "Received response from OpenAI API: $response", "OpenAIChatPlugin";
        sendChatResponse($response, $args->{privMsgUser} ? 'priv' : 'pub', $args);
    } else {
        # Handle casual chat messages
        Log::message "Received casual chat message\n", "OpenAIChatPlugin";
        my $chatContext = join("\n", @chatLog);
        my $response;
        eval {
            Log::message "Sending to openai\n", "OpenAIChatPlugin";
            $response = $openAIClient->sendRequest($prompt, $chatContext);
        };
        if ($@) {
            Log::error "Error sending request to OpenAI API: $@", "OpenAIChatPlugin";
            return;
        }

        Log::message "Received response from OpenAI API: $response\n", "OpenAIChatPlugin";
        sendChatResponse($response, $args->{privMsgUser} ? 'priv' : 'pub', $args);
    }
}

sub sendChatResponse {
    my ($response, $channel, $args) = @_;

    # Format the response for chat display
    my $formattedResponse = "AI Response: $response";
    Log::message "Formatted response: $formattedResponse", "OpenAIChatPlugin";

    # Send the response to the appropriate channel
    if ($channel eq 'priv') {
        Log::message "Sending private message to $args->{privMsgUser}", "OpenAIChatPlugin";
        sendMessage($messageSender, 'pm', $formattedResponse, $args->{privMsgUser});
        Log::message "Private message sent successfully", "OpenAIChatPlugin";
    } else {
        Log::message "Sending message to $channel channel: $formattedResponse, sender: $messageSender", "OpenAIChatPlugin";
        sendMessage($messageSender, 'c', $formattedResponse);
        Log::message "Public message sent successfully", "OpenAIChatPlugin";
    }

    # Add the response to the chat log
    my $timestamp = time();
    push @chatLog, "[$timestamp] AI: $response";
    shift @chatLog if scalar(@chatLog) > $maxChatLogLines;
    Log::message "Response added to chat log", "OpenAIChatPlugin";
}

sub unload {
    # Remove hooks when unloading the plugin
    Plugins::delHook($_, $chatHooks{$_}) for keys %chatHooks;
}

Load:

$chatHooks{packet_privMsg} = Plugins::addHook('packet_privMsg', \&handleChatMessage);
$chatHooks{packet_pubMsg} = Plugins::addHook('packet_pubMsg', \&handleChatMessage);
$chatHooks{packet_partyMsg} = Plugins::addHook('packet_partyMsg', \&handleChatMessage);
$chatHooks{packet_guildMsg} = Plugins::addHook('packet_guildMsg', \&handleChatMessage);

Log::message "OpenAI Chat Plugin loaded\n", "OpenAIChatPlugin";

1;

