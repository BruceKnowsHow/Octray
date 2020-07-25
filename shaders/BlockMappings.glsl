#if MC_VERSION >= 11300
	int BackPortID(int ID) {
		if (ID == -1) return 1; // un-assigned blocks in 1.13+
		
		return ID;
	}
#else
	int BackPortID(int ID) {
		return ID;
	}
#endif

#if (defined gbuffers_entities)
	#define BackPortID(ID) 0
#endif


#define UNHANDLED_BLOCKS 1  // [0 1 2]

bool isSimpleVoxel(int ID)  { return ID == 2; }
bool isEntity(int ID)       { return ID == 0; }
bool isLeavesType(int ID)   { return (ID % 64) == 3; }
bool isGlassType(int ID)    { return (ID % 64) == 4; }
bool isEmissive(int ID)     { return (ID & 64) > 0 && (ID != 250); }
bool isWater(int ID)        { return ID == 21; }
bool isBackFaceType(int ID) { return ID == 3 || ID == 4; }
bool isSapling(int ID)      { return ID == 5; }
bool isTallGrass(int ID)    { return ID == 7; }
bool isSubVoxel(int ID)     { return ID == 8 || ID == 12; }
bool isVoxelized(int ID)    { return isSubVoxel(ID) || (!isEntity(ID)) && (ID != 1) && (ID < 5 || ID == 8 || ID == 66 || ID >= 85 || ID == 75) && (ID != 250); }
