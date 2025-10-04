# Aottg2 Bad Apple

[YOUTUBE LINK](https://www.youtube.com/watch?v=W_pkhx25Un8)

## Goal

I wanted to be able to be able to stream the video to players in the room
without downloading Custom Assets or prior setup.

## Setup

1. Download `show-video.cl` into your Custom Logic folder, usually `Documents/Aottg2/CustomLogic`.
2. Download `VIDEO.txt` into your Persistent Data folder, usually `Documents/Aottg2/PersistentData`.
3. Host a room with `show-video` mode selected.

## Generating a video with the script.

This script requires `pillow`. You can install it with the following command:
> pip install pillow

You can then run
> python convert.py

and it will read `bad_apple.gif` and convert output into `VIDEO.txt`.

## How it works.

The basic idea is just converting each frame into unicode text, using color tags.
This is then chunked and sent over NetworkMessages, where after it is received, it is simply displayed using `UI.SetLabel`.
However, the uncompressed form may take too much bandwidth, and/or may not load as fast the video plays.
To solve this, I implemented some basic compression in CL.
The python script encodes the each frame of the video using LZW, and the CL script decodes accordingly.
I do think for just Bad Apple I could have just done something even simpler, like run length encoding.
However, this may not be as feasible for videos/images with the colour palette would dramatically increase and alternate, not allowing RLE to be particularly effective.
Another benefit of LZW/dictionary compression is that it defers alot of its computation to the game, such as doing dictionary retrieval or large string concatenation.
One major issue is that CL is not particularly geared to handle processing a large amount of data.
So the compression step should not be too heavy so as to affect performane.

## Further experimentation and work.

I have tried with colours, and am able to send a coloured image over the network. However, coloured images can't seem to be feasily played in an animation.
It seems that for larger texts, it causes lag when doing `UI.SetLabel`.
I think using different shades of the unicode block, like `█▓▒░` could further reduce redundancy.
However, apparently some people encountered alignment issues with that approach (but I could just be using the wrong characters).
