## Akkio's Consume Helper - Shopping List Feature

### Version 1.1.0 - Smart Shopping List Feature

The Shopping List feature provides intelligent consumable tracking to help you maintain your buff supplies efficiently.

#### **Core Features:**
- **Smart Shopping List**: Automatically tracks all enabled buffs and shows missing consumables
- **Real-time Updates**: Dynamically refreshes based on your current inventory and buff status
- **Comprehensive Coverage**: Shows ALL consumables you're tracking but don't have in bags
- **Professional Interface**: Consistent styling with main addon windows

#### **How to Use:**
1. Type `/actshop` to open the smart shopping list
2. The list displays all consumables you're tracking but currently missing from your bags
3. Items are organized for easy shopping reference
4. Window auto-updates when you acquire items or change your tracked buffs
5. Clean, professional interface matches the main addon design

#### **Key Benefits:**
- **Only shows relevant items**: Displays consumables for buffs you've actually enabled
- **Zero configuration**: Works automatically with your existing buff selections  
- **Real-time accuracy**: Immediately reflects changes in your inventory
- **Shopping efficiency**: Never forget consumables or buy unnecessary items
- **Integrated experience**: Seamlessly works with existing buff tracking system

#### **Technical Implementation:**
- Modular design in dedicated `Akkio_Consume_Helper_ShoppingList.lua` file
- Integrated with main addon's item detection system
- Efficient bag scanning with smart caching
- UI using standard WoW frame templates
- Cross-compatible with all existing addon features

#### **Usage Commands:**
- `/actshop` - Opens the smart shopping list window

**Perfect for:** Preparation before raids, dungeon runs, or any content where you want to ensure you have all your consumables ready!

The shopping list displays "All consumables are available!" when you have everything you need.
