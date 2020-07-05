## Octray
![Teaser Image](https://cdn.discordapp.com/attachments/254127148913262593/718599693927710770/wide.jpg)

Octray is an experimental raytraced shaderpack for Minecraft/Optifine.

**What is unique about Octray?**

Octray implements an Octree-like acceleration structure for its raytracing. This allows rays to be cast long distances in sparse environments with significantly fewer intersection-checks.

For example, with 16x chunk render distance, a naive voxel intersection algorithm would need 512 intersection checks at minimum to propagate light from one side of the render region to the other. In a typical environment, Octray's voxel intersection algorithm will need ~32 intersection checks to do the same thing.

**But at what cost?**
- The Octal data structure requires an additional ~14% storage space.
- The voxel intersection algorithm can be slightly slower in rare worst-case environments.
- Generating the data structure is a little slow if you don't use a geometry shader (shadow.gsh).

**How does it work?**

Octray's acceleration structure is simply a regular voxelized volume with 7 additional LOD volumes. Each LOD volume is 1/2 the resolution of the previous one (in 3D this means each volume takes 1/8 the space of previous one). Querying a LOD volume allows you to ask "does this larger area of space contain any blocks at all"? For example, sampling from the LOD=3 voxel volume is equivalent to asking if there are any blocks in an 8x8x8 volume. If the volume contains a lot of contiguous empty space (like Minecraft worlds often do), then this allows casting rays through large distances with significantly fewer samples.
