# GenMagic for Godot

A dock for the Godot editor that generates images (sprites, textures, concept art), lines of dialogue and music from about 460 AI models, with one API key and one pay-as-you-go balance. Results are saved under `res://genmagic/` and appear in the FileSystem dock.

Needs Godot 4.2 or newer. Plain GDScript, MIT licensed.

## Set up

1. Enable the plugin: **Project > Project Settings > Plugins > GenMagic**.
2. Create an API key at https://genmagic.co/get-api-key and paste it into the key box in the GenMagic dock (right side, next to the Inspector).

The key is stored in your per-user **Editor Settings** (`genmagic/api_key`), never in the project, so it is never committed to version control.

## Use

Pick **Image**, **Speech** or **Music**, describe what you want, optionally choose a model (each shows its estimated price), and press **Generate**. The dock shows what it cost and the balance left. Files are saved in `res://genmagic/images`, `speech` and `music` with a readable name.

## Cost and privacy

GenMagic is a paid, pay-as-you-go service (new accounts get a small starter balance). Nothing is spent until you press Generate. Your prompt, and any reference image you choose, is sent to GenMagic and to the provider of the model you pick. The plugin makes no network request until you open its dock. See https://genmagic.co/legal/privacy.

Full documentation, troubleshooting and the source: see the repository README. Support: hello@genmagic.co.
