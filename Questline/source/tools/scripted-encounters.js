// Presentation guidance from the upstream compiled snapshot, scoped by role.
function scriptedEncounter(db,id,role) {
  if (db.units[id]?.coordinates?.length) return undefined;
  const record=db.scriptedEncounters[id];
  if (!record?.roles[role]) return undefined;
  const coordinates=record.coordinates.length?record.coordinates:db.objects[record.anchorObject]?.coordinates;
  return coordinates?.length?{...record,coordinates}:undefined;
}
module.exports={scriptedEncounter};
