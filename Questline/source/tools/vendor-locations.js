// Questie-Octo is the authority for vendor availability. Keep every recorded
// vendor so nearby suppliers remain useful quest destinations.
function mappedVendors(item) {
  return Object.keys(item.vendors||{});
}
module.exports={mappedVendors};
