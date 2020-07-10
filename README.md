## Octray
![Image](https://cdn.discordapp.com/attachments/254127148913262593/730198439706755153/wide.jpg)

Octray is an experimental raytraced shaderpack for Minecraft/Optifine.

**What is remarkable about Octray?**

Octray implements an Octree-like acceleration structure for its raytracing. This allows rays to be cast long distances in sparse environments with significantly fewer intersection-checks.

Octray also contains a few other inventions, such as a pseudo-recursive branching GLSL raytracer, implemented using a ray stack.

## Installation
Octray can be installed the same as any other Minecraft shaderpack. Just download the .zip from GitHub and place it into your shaderpacks folder.

If you have never installed a shaderpack before, there are lots of videos on Youtube to walk you through it. [Here is one](https://www.youtube.com/watch?v=XNLVHl4s8rA).

## Compatibility
As of writing, Octray should be compatible with:
- Nvidia, AMD and Intel hardware
- Every version of Minecraft from 1.8 through 1.16

#### AMD / Intel fix for Minecraft 1.15 and 1.16
Due to a current bug in Minecraft/Optifine 1.15 & 1.16, AMD and Intel users must do the following to disable geometry shaders, which are not functioning:
1. Unzip the shaderpack. It does not need to be zipped to be loaded by Minecraft.
2. Navigate to `shaders/world0/` and delete the file named "shadow.gsh"
4. If you plan to play in the Nether or the End, do the same in `shaders/world-1/` and `shaders/world1/`
5. In the Octray shader settings menu, set the option `Debug->Secret Stuff->Geometry Shader: Disabled`
