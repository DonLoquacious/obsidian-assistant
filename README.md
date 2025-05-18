# Obsidian AI-Powered Project Assistant

Welcome to the repository! This repo largely contains a set of Bash scripts designed to streamline the integration of our Obsidian note directories with an AI "assistant", powered by OpenAI.

By largely configuring the assistant AI for us, the system ensures that your assistant has access to the data it needs to be able to response accurately, and that it will always attempt to use that project data if a question would seem to be benefit from it. You can also provide your own instructions and adjustments to the configuration if needed though- instructions you give will be used on top of the existing instructions, so the assistant will still prefer to search for answers if there are any to be found in the project files- that was our goal, after all.

Please be warned that this has the impact of queries which rack up quite a few more tokens than one might expect. This setup is meant more for "personal assistant" and small-team scenarios than those where clients are directly interacting with the GPT- using an assistant AI in order to speed up productivity on a given project by ensuring that it has all of the information that it needs to be accurate.

## Overview

This project helps you:
- Interface with OpenAI's API to create/keep your assistant AI up-to-date with your latest instructions, defined in a simple text file in your Obsidian project (can be easily copied from a provided template).
- Keep all of your project files updated in an OpenAI "vector store", so that they're accessible to your assistant AI.
- Compile all of your project files into one big JSON blob, for easier consumption by some systems.
- Create AI-powered summaries of each of your project files, collecting all of these into a single quick-reference, so that the assistant can better choose where it should be looking for additional information.
- More coming...

## Prerequisites

- You must have OpenAI API credits on your account, or the REST API can't be used.
- You must export/set your OpenAI API token to your ENVs as "OPENAI_API_KEY"
  - https://platform.openai.com/api-keys
  - Typically, in the terminal: `export OPENAI_API_KEY="your-openai-api-key"`

## Steps

- run `export OPENAI_API_KEY="your-openai-api-key"` with your API key, to set that to an ENV and make it accessible from the bash scripts
- run `make`
  - you may be told that a new instructions file was created/copied from a template for you
  - edit this in ./Assistant/ASSISTANT_INSTRUCTIONS, in Obsidian or any text editor of your choice- fill out the configuration however you like
- run `make` again
- profit
  - the Assistant AI will be created/updated
  - all markdown files in the project will be uploaded to the vector store and made searchable

## Update assistant AI configuration, or project files
- run `make` again
