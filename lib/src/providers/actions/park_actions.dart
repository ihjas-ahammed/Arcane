// lib/src/providers/actions/park_actions.dart
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'dart:math'; // For Random

class ParkActions {
  final GameProvider _provider;
  final Random _random = Random();


  ParkActions(this._provider);

  void _logToPark(String message, {bool isError = false}) {
    final color = isError ? AppTheme.fhAccentRed : AppTheme.fhAccentGreen;
    final logMessage = "<span style=\"color:${color.value.toRadixString(16).substring(2)};\">[Park] $message</span>";
    print("[ParkActions Log] $message");
    _provider.setProviderState(
        currentGame: CurrentGame(
            enemy: _provider.currentGame.enemy,
            playerCurrentHp: _provider.currentGame.playerCurrentHp,
            log: [..._provider.currentGame.log, logMessage],
            currentPlaceKey: _provider.currentGame.currentPlaceKey),
        doPersist: false,
        doNotify: true
    );
  }

  bool canAffordBuilding(BuildingTemplate buildingTemplate) {
    return _provider.parkManager.parkDollars >= buildingTemplate.costDollars;
  }

  void buyAndPlaceBuilding(String buildingTemplateId) {
    final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == buildingTemplateId);
    if (template == null) {
      _logToPark("Error: Building blueprint not found.", isError: true);
      return;
    }

    if (!canAffordBuilding(template)) {
      _logToPark("Cannot afford ${template.name}. Cost: \$${template.costDollars}.", isError: true);
      return;
    }

    bool canBeOperationalInitially = true;
    if ((template.powerRequired ?? 0) > 0 && template.type != "power_plant") {
        final totalPowerGenerated = _provider.parkManager.currentPowerGenerated;
        final totalPowerConsumedByOthers = _provider.parkManager.currentPowerConsumed;

        if (totalPowerGenerated < totalPowerConsumedByOthers + (template.powerRequired ?? 0)) {
            canBeOperationalInitially = false;
            _logToPark("${template.name} constructed but offline due to insufficient power.", isError: true);
        }
    }


    final newBuilding = OwnedBuilding(
      uniqueId: 'ob_${DateTime.now().millisecondsSinceEpoch}_${template.id.hashCode}',
      templateId: template.id,
      currentFoodLevel: template.type == "food_station" ? enclosureBaseFoodCapacity : null,
      isOperational: template.type == "power_plant" ? true : canBeOperationalInitially,
    );

    final List<OwnedBuilding> updatedOwnedBuildings = [..._provider.ownedBuildings, newBuilding];
    final double newParkDollars = _provider.parkManager.parkDollars - template.costDollars;

    _provider.setProviderState(
      parkManager: _provider.parkManager..parkDollars = newParkDollars,
      ownedBuildings: updatedOwnedBuildings,
      doPersist: true,
      doNotify: true,
    );

    _logToPark("Constructed ${template.name}!");
    _recalculateParkStats(); // This will also update power status
  }

  void sellBuilding(String ownedBuildingUniqueId) {
    final ownedBuilding = _provider.ownedBuildings.firstWhereOrNull((b) => b.uniqueId == ownedBuildingUniqueId);
    if (ownedBuilding == null) {
        _logToPark("Error: Building not found in park.", isError: true);
        return;
    }
    final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == ownedBuilding.templateId);
    if (template == null) {
        _logToPark("Error: Building blueprint corrupted for owned building.", isError: true);
        return;
    }

    final double sellPercentage = 0.5;
    final int sellPrice = (template.costDollars * sellPercentage).floor();

    List<OwnedBuilding> updatedOwnedBuildings = _provider.ownedBuildings.where((b) => b.uniqueId != ownedBuildingUniqueId).toList();
    final double newParkDollars = _provider.parkManager.parkDollars + sellPrice;
    List<OwnedDinosaur> updatedOwnedDinosaurs = List.from(_provider.ownedDinosaurs);

    if (template.type == "enclosure" && ownedBuilding.dinosaurUniqueIds.isNotEmpty) {
        updatedOwnedDinosaurs = _provider.ownedDinosaurs
            .where((dino) => !ownedBuilding.dinosaurUniqueIds.contains(dino.uniqueId))
            .toList();
        _logToPark("Dinosaurs from demolished ${template.name} have been released to the wild (removed from park).", isError: true);
    }

    _provider.setProviderState(
      parkManager: _provider.parkManager..parkDollars = newParkDollars,
      ownedBuildings: updatedOwnedBuildings,
      ownedDinosaurs: template.type == "enclosure" ? updatedOwnedDinosaurs : null, // Only update if it was an enclosure
      doPersist: true,
      doNotify: true,
    );
    _logToPark("Demolished ${template.name}. Recovered \$$sellPrice.");
    _recalculateParkStats();
  }

  void excavateFossil(String speciesId) {
    final species = _provider.dinosaurSpeciesList.firstWhereOrNull((s) => s.id == speciesId);
    if (species == null) {
        _logToPark("Species $speciesId not found for excavation.", isError: true);
        return;
    }
     final bool fossilCenterOperational = _provider.ownedBuildings.any((b) {
        final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == b.templateId);
        return template?.type == "fossil_center" && b.isOperational;
    });
    if (!fossilCenterOperational) {
        _logToPark("Fossil Center is not operational. Cannot excavate.", isError: true);
        return;
    }

    if (_provider.playerEnergy < species.fossilExcavationEnergyCost) { // Use player energy
      _logToPark("Not enough player energy to excavate. Cost: ${species.fossilExcavationEnergyCost}⚡", isError: true);
      return;
    }
     if (_provider.playerLevel < species.minPlayerLevelToUnlock) {
      _logToPark("Player level too low to excavate ${species.name}. Requires level ${species.minPlayerLevelToUnlock}.", isError: true);
      return;
    }


    final recordIndex = _provider.fossilRecords.indexWhere((fr) => fr.speciesId == speciesId);
    if (recordIndex == -1) {
      _logToPark("Fossil record for species $speciesId not found.", isError: true);
      return;
    }
    final record = _provider.fossilRecords[recordIndex];
    if (record.isGenomeComplete) {
      _logToPark("Genome for ${record.speciesId} is already complete.", isError: false);
      return;
    }

    final double progressIncrease = 10.0 + _random.nextDouble() * 15.0; // 10-25% progress
    record.excavationProgress = (record.excavationProgress + progressIncrease).clamp(0.0, 100.0);
    if (record.excavationProgress >= 100.0) {
      record.isGenomeComplete = true;
      _logToPark("Genome for ${record.speciesId} is now 100% complete and ready for incubation!");
    } else {
      _logToPark("Fossil excavation for ${record.speciesId} progressed to ${record.excavationProgress.toStringAsFixed(1)}%.");
    }
    
    final List<FossilRecord> updatedRecords = List.from(_provider.fossilRecords);
    updatedRecords[recordIndex] = record;

    _provider.setProviderState(
      fossilRecords: updatedRecords,
      playerEnergy: _provider.playerEnergy - species.fossilExcavationEnergyCost, // Deduct player energy
      doPersist: true,
      doNotify: true
    );
  }

  void incubateDinosaur(String speciesId) {
    final species = _provider.dinosaurSpeciesList.firstWhereOrNull((s) => s.id == speciesId);
    if (species == null) {
      _logToPark("Species $speciesId not found for incubation.", isError: true);
      return;
    }
    if (_provider.playerLevel < species.minPlayerLevelToUnlock) {
        _logToPark("Player level too low to incubate ${species.name}. Requires level ${species.minPlayerLevelToUnlock}.", isError: true);
        return;
    }
    final fossilRecord = _provider.fossilRecords.firstWhereOrNull((fr) => fr.speciesId == speciesId);
    if (fossilRecord == null || !fossilRecord.isGenomeComplete) {
      _logToPark("Genome for ${species.name} is not complete. Excavate more fossils.", isError: true);
      return;
    }
    if (_provider.parkManager.parkDollars < species.incubationCostDollars) {
      _logToPark("Not enough park funds to incubate ${species.name}. Cost: \$${species.incubationCostDollars}.", isError: true);
      return;
    }
    if (_provider.playerEnergy < incubationEnergyCost) { // Use player energy
       _logToPark("Not enough player energy to incubate ${species.name}. Cost: $incubationEnergyCost⚡.", isError: true);
      return;
    }

    // Check if a hatchery is available and has capacity
    final operationalHatcheries = _provider.ownedBuildings.where((b) {
        final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == b.templateId);
        return template?.type == "hatchery" && b.isOperational;
    }).toList();

    if (operationalHatcheries.isEmpty) {
        _logToPark("No operational hatchery available to incubate dinosaurs.", isError: true);
        return;
    }
    
    int totalHatcheryCapacity = operationalHatcheries.fold(0, (sum, hatchery) {
        final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == hatchery.templateId);
        return sum + (template?.capacity ?? 0);
    });
    
    final incubatingDinosCount = _provider.ownedDinosaurs.where((d) => d.name.contains("(Incubating)")).length;
    if (incubatingDinosCount >= totalHatcheryCapacity) {
         _logToPark("All hatcheries are at full capacity. Wait for current incubations to finish.", isError: true);
        return;
    }


    final newDinosaur = OwnedDinosaur(
      uniqueId: 'dino_${DateTime.now().millisecondsSinceEpoch}_${species.id.hashCode}',
      speciesId: species.id,
      name: "${species.name} (Incubating)", // Indicate status
      age: 0, // Represents incubation progress
    );

    _provider.setProviderState(
      parkManager: _provider.parkManager..parkDollars -= species.incubationCostDollars,
      playerEnergy: _provider.playerEnergy - incubationEnergyCost, // Deduct player energy
      ownedDinosaurs: [..._provider.ownedDinosaurs, newDinosaur],
      doPersist: true,
      doNotify: true
    );
    _logToPark("Incubation started for a ${species.name}!");
  }

  void addDinosaurToEnclosure(String dinosaurUniqueId, String enclosureUniqueId) {
    final dinosaur = _provider.ownedDinosaurs.firstWhereOrNull((d) => d.uniqueId == dinosaurUniqueId);
    final enclosure = _provider.ownedBuildings.firstWhereOrNull((b) => b.uniqueId == enclosureUniqueId);
    final enclosureTemplate = enclosure != null ? _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == enclosure.templateId) : null;

    if (dinosaur == null || enclosure == null || enclosureTemplate == null || enclosureTemplate.type != "enclosure") {
      _logToPark("Invalid dinosaur or enclosure for transfer.", isError: true);
      return;
    }
    if (!enclosure.isOperational) {
        _logToPark("${enclosureTemplate.name} is not operational. Cannot add dinosaurs.", isError: true);
        return;
    }
    if (enclosure.dinosaurUniqueIds.length >= (enclosureTemplate.capacity ?? 999)) {
        _logToPark("${enclosureTemplate.name} is at full capacity.", isError: true);
        return;
    }
    if(dinosaur.name.contains("(Incubating)")) {
        _logToPark("${dinosaur.name} is still incubating and cannot be moved.", isError: true);
        return;
    }


    final List<OwnedBuilding> updatedBuildings = _provider.ownedBuildings.map((b) {
      if (b.uniqueId == enclosureUniqueId) {
        return OwnedBuilding(
          uniqueId: b.uniqueId,
          templateId: b.templateId,
          dinosaurUniqueIds: [...b.dinosaurUniqueIds, dinosaurUniqueId],
          currentFoodLevel: b.currentFoodLevel,
          isOperational: b.isOperational,
        );
      }
      return b;
    }).toList();

    _provider.setProviderState(
      ownedBuildings: updatedBuildings,
      doPersist: true,
      doNotify: true
    );
    _logToPark("${dinosaur.name} moved to ${enclosureTemplate.name}.");
    _recalculateParkStats();
  }

  void feedDinosaursInEnclosure(String enclosureUniqueId, int amount) {
    final enclosure = _provider.ownedBuildings.firstWhereOrNull((b) => b.uniqueId == enclosureUniqueId);
     if (enclosure == null) {
        _logToPark("Enclosure not found for feeding.", isError: true);
        return;
    }
    // Find an associated food station. Simplified: assumes one generic food station for the park or per enclosure.
    // For more complex scenarios, link food stations to enclosures.
    final foodStationIndex = _provider.ownedBuildings.indexWhere((b) {
        final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == b.templateId);
        // Assuming food stations are generic for now and not tied to specific enclosures in data model
        // If they were, would add: && b.linkedEnclosureId == enclosureUniqueId
        return template?.type == "food_station" && b.isOperational; 
    });

    if (foodStationIndex == -1) {
        _logToPark("No operational food station found.", isError: true); // Generic message if not linked
        return;
    }
    if (_provider.playerEnergy < feedDinoEnergyCost) { // Check player energy
        _logToPark("Not enough player energy to refill feeder. Cost: $feedDinoEnergyCost⚡", isError: true);
        return;
    }
    
    final List<OwnedBuilding> updatedBuildings = List.from(_provider.ownedBuildings);
    final foodStation = updatedBuildings[foodStationIndex];
    final newFoodLevel = (foodStation.currentFoodLevel ?? 0) + amount;
    updatedBuildings[foodStationIndex] = OwnedBuilding(
        uniqueId: foodStation.uniqueId,
        templateId: foodStation.templateId,
        dinosaurUniqueIds: foodStation.dinosaurUniqueIds,
        currentFoodLevel: newFoodLevel.clamp(0, enclosureBaseFoodCapacity),
        isOperational: foodStation.isOperational
    );

    _provider.setProviderState(
        ownedBuildings: updatedBuildings,
        playerEnergy: _provider.playerEnergy - feedDinoEnergyCost, // Deduct player energy
        doPersist: true,
        doNotify: true
    );
    _logToPark("Refilled food by $amount. New level: ${updatedBuildings[foodStationIndex].currentFoodLevel}.");
  }

  void toggleBuildingOperationalStatus(String ownedBuildingUniqueId) {
    final ownedBuilding = _provider.ownedBuildings.firstWhereOrNull((b) => b.uniqueId == ownedBuildingUniqueId);
    if (ownedBuilding == null) return;
    final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == ownedBuilding.templateId);
    if (template == null) return;

    bool currentStatus = ownedBuilding.isOperational;
    bool newStatus = !currentStatus;
    List<OwnedBuilding> tempUpdatedBuildings = List.from(_provider.ownedBuildings);
    int buildingIndex = tempUpdatedBuildings.indexWhere((b) => b.uniqueId == ownedBuildingUniqueId);

    if (newStatus) { // Attempting to turn ON
        if ((template.powerRequired ?? 0) > 0) { // Only check for consumers
            int totalPowerGenerated = _provider.parkManager.currentPowerGenerated;
            
            if (template.type == "power_plant") {
                // This case is fine, power plants don't consume to turn on
            } else { // Consumer building
                int currentTotalPowerConsumedByOthers = _provider.parkManager.currentPowerConsumed;
               
                if (totalPowerGenerated < currentTotalPowerConsumedByOthers + (template.powerRequired ?? 0)) {
                    _logToPark("Cannot turn on ${template.name}. Insufficient power. Available: $totalPowerGenerated, Required (incl. this): ${currentTotalPowerConsumedByOthers + (template.powerRequired ?? 0)}", isError: true);
                    return; // Don't change status
                }
            }
        }
    }
    
    // If we reach here, the toggle is permissible
    tempUpdatedBuildings[buildingIndex] = OwnedBuilding(
        uniqueId: ownedBuilding.uniqueId,
        templateId: ownedBuilding.templateId,
        dinosaurUniqueIds: ownedBuilding.dinosaurUniqueIds,
        currentFoodLevel: ownedBuilding.currentFoodLevel,
        isOperational: newStatus,
    );
    
    _provider.setProviderState(
      ownedBuildings: tempUpdatedBuildings,
      doPersist: false, // Recalculate will persist
      doNotify: true,
    );
    
    _logToPark("${template.name} is now ${newStatus ? 'operational' : 'offline'}.", isError: !newStatus);
    _recalculateParkStats(); // This will update power grid and persist
  }


  void _updateBuildingOperationalStatusBasedOnPower() {
    int totalPowerGenerated = 0;
    int totalPowerRequiredByOperationalConsumers = 0;
    List<OwnedBuilding> currentBuildings = List.from(_provider.ownedBuildings); 

    for (var building in currentBuildings) {
        final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == building.templateId);
        if (template == null) continue;

        if (template.type == "power_plant" && building.isOperational) {
            totalPowerGenerated += template.powerOutput ?? 0;
        } else if (template.type != "power_plant" && building.isOperational) {
            totalPowerRequiredByOperationalConsumers += template.powerRequired ?? 0;
        }
    }
    
    bool changesMadeToOperationalStatus = false;
    if (totalPowerRequiredByOperationalConsumers > totalPowerGenerated) {
        _logToPark("Power shortage! Demand ($totalPowerRequiredByOperationalConsumers) exceeds supply ($totalPowerGenerated). Attempting to manage load...", isError: true);
        
        List<OwnedBuilding> consumersToPotentiallyTurnOff = currentBuildings
            .where((b) {
                final t = _provider.buildingTemplatesList.firstWhereOrNull((tmpl) => tmpl.id == b.templateId);
                return t?.type != "power_plant" && b.isOperational && (t?.powerRequired ?? 0) > 0;
            })
            .toList()
            ..sort((a, b) {
                final ta = _provider.buildingTemplatesList.firstWhere((t) => t.id == a.templateId);
                final tb = _provider.buildingTemplatesList.firstWhere((t) => t.id == b.templateId);
                return (tb.powerRequired ?? 0).compareTo(ta.powerRequired ?? 0);
            });

        int currentDemand = totalPowerRequiredByOperationalConsumers;
        for (var buildingToTurnOff in consumersToPotentiallyTurnOff) {
            if (currentDemand <= totalPowerGenerated) break; 

            final template = _provider.buildingTemplatesList.firstWhere((t) => t.id == buildingToTurnOff.templateId);
            int buildingIndex = currentBuildings.indexWhere((b) => b.uniqueId == buildingToTurnOff.uniqueId);
            
            if (buildingIndex != -1 && currentBuildings[buildingIndex].isOperational) { 
                currentBuildings[buildingIndex] = OwnedBuilding(
                    uniqueId: buildingToTurnOff.uniqueId,
                    templateId: buildingToTurnOff.templateId,
                    dinosaurUniqueIds: buildingToTurnOff.dinosaurUniqueIds,
                    currentFoodLevel: buildingToTurnOff.currentFoodLevel,
                    isOperational: false, 
                );
                currentDemand -= (template.powerRequired ?? 0);
                _logToPark("${template.name} turned offline due to power shortage.", isError: true);
                changesMadeToOperationalStatus = true;
            }
        }
        totalPowerRequiredByOperationalConsumers = currentDemand; 
    }

    _provider.setProviderState(
        ownedBuildings: changesMadeToOperationalStatus ? currentBuildings : null, 
        parkManager: _provider.parkManager
            ..currentPowerGenerated = totalPowerGenerated
            ..currentPowerConsumed = totalPowerRequiredByOperationalConsumers,
        doPersist: true, 
        doNotify: true 
    );
}


  void updateAllDinosaursStatus() {
    if (_provider.ownedDinosaurs.isEmpty) return;
    bool changed = false;

    final List<OwnedDinosaur> updatedDinos = _provider.ownedDinosaurs.map((dino) {
        final species = _provider.dinosaurSpeciesList.firstWhereOrNull((s) => s.id == dino.speciesId);
        if (species == null) return dino; 

        OwnedDinosaur updatedDino = OwnedDinosaur.fromJson(dino.toJson()); 

        if (updatedDino.name.contains("(Incubating)")) {
            // Incubation progress already handled by processParkTime via _provider.activeTimers
            return updatedDino; // No further changes here if still incubating
        }

        // For hatched dinosaurs:
        updatedDino.age +=1; 

        updatedDino.currentFood = (updatedDino.currentFood - (_random.nextDouble() * 2 + 1)).clamp(0.0, 100.0); 

        double comfortImpact = 0;
        final enclosure = _provider.ownedBuildings.firstWhereOrNull((b) => b.dinosaurUniqueIds.contains(dino.uniqueId));
        
        if (enclosure != null) {
            final enclosureTemplate = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == enclosure.templateId);
            if (enclosureTemplate != null) {
                final dinosInSameEnclosure = enclosure.dinosaurUniqueIds.length;
                if (dinosInSameEnclosure < species.socialNeedsMin || dinosInSameEnclosure > species.socialNeedsMax) {
                    comfortImpact -= 5;
                } else {
                    comfortImpact += 2;
                }
                if (enclosureTemplate.capacity != null && species.enclosureSizeNeeds * dinosInSameEnclosure > enclosureTemplate.capacity! * 5 ) {
                     comfortImpact -= 3; 
                }
            }
            final foodStation = _provider.ownedBuildings.firstWhereOrNull((b) {
                final fTemplate = _provider.buildingTemplatesList.firstWhereOrNull((ft) => ft.id == b.templateId);
                return fTemplate?.type == "food_station" && b.isOperational;
            });
            if (foodStation != null && (foodStation.currentFoodLevel ?? 0) > 0) {
                final int foodConsumed = _random.nextInt(5) + 1; 
                final newFoodStationLevel = (foodStation.currentFoodLevel ?? 0) - foodConsumed;
                 List<OwnedBuilding> tempBuildings = List.from(_provider.ownedBuildings);
                 int fsIndex = tempBuildings.indexWhere((b) => b.uniqueId == foodStation.uniqueId);
                 if (fsIndex != -1) {
                    tempBuildings[fsIndex] = OwnedBuilding(
                        uniqueId: foodStation.uniqueId,
                        templateId: foodStation.templateId,
                        dinosaurUniqueIds: foodStation.dinosaurUniqueIds,
                        isOperational: foodStation.isOperational,
                        currentFoodLevel: newFoodStationLevel.clamp(0, enclosureBaseFoodCapacity)
                    );
                     _provider.setProviderState(ownedBuildings: tempBuildings, doPersist: false, doNotify: false); 
                     changed = true;
                 }
                updatedDino.currentFood = (updatedDino.currentFood + foodConsumed * 5).clamp(0.0, 100.0); 
            }


        } else {
            comfortImpact -= 10; 
        }

        if (updatedDino.currentFood < 20) {
          comfortImpact -= 10;
        } else if (updatedDino.currentFood < 50) comfortImpact -= 5;
        else if (updatedDino.currentFood > 80) comfortImpact += 3;

        updatedDino.currentComfort = (updatedDino.currentComfort + comfortImpact).clamp(0.0, 100.0);

        if (updatedDino.currentComfort < species.comfortThreshold * 100 * 0.5) { 
            updatedDino.currentHealth = (updatedDino.currentHealth - 2).clamp(0.0, 100.0);
        }
        if (updatedDino.currentFood < 10) {
            updatedDino.currentHealth = (updatedDino.currentHealth - 3).clamp(0.0, 100.0);
        }

        if (dino.currentComfort != updatedDino.currentComfort || dino.currentFood != updatedDino.currentFood || dino.currentHealth != updatedDino.currentHealth || dino.name != updatedDino.name || dino.age != updatedDino.age) {
            changed = true;
        }
        return updatedDino;
    }).toList();

    if (changed) {
        _provider.setProviderState(ownedDinosaurs: updatedDinos, doPersist: true, doNotify: true);
        _recalculateParkStats(); 
    }
}



  void _recalculateParkStats() {
    _updateBuildingOperationalStatusBasedOnPower(); 

    int newParkRating = 0;
    int newIncomePerMinuteDollars = 0;
    int newOperationalCostPerMinuteDollars = 0;
    
    int currentPowerGenerated = 0;
    int currentPowerConsumed = 0;

    for (var ownedBuilding in _provider.ownedBuildings) { 
      final template = _provider.buildingTemplatesList.firstWhereOrNull((t) => t.id == ownedBuilding.templateId);
      if (template != null && ownedBuilding.isOperational) { 
        newParkRating += template.parkRatingBoost ?? 0;
        newIncomePerMinuteDollars += template.incomePerMinuteDollars ?? 0;
        newOperationalCostPerMinuteDollars += template.operationalCostPerMinuteDollars ?? 0;
        
        if (template.type == "power_plant") {
            currentPowerGenerated += template.powerOutput ?? 0;
        } else {
            currentPowerConsumed += template.powerRequired ?? 0;
        }
      }
    }
    
    for (var ownedDino in _provider.ownedDinosaurs) {
        final species = _provider.dinosaurSpeciesList.firstWhereOrNull((s) => s.id == ownedDino.speciesId);
        if (species != null && !ownedDino.name.contains("(Incubating)")) { 
            double ratingModifier = 1.0;
            if(ownedDino.currentComfort < species.comfortThreshold * 100) ratingModifier *= 0.5; 
            if(ownedDino.currentHealth < 50) ratingModifier *= 0.7; 
            newParkRating += (species.baseRating * ratingModifier).round();
        }
    }
    newParkRating = newParkRating.clamp(0, MAX_PARK_RATING_FOR_STARS * 2); 

    _provider.setProviderState(
      parkManager: ParkManager(
        parkRating: newParkRating,
        parkDollars: _provider.parkManager.parkDollars, 
        parkEnergy: _provider.playerEnergy, 
        maxParkEnergy: _provider.calculatedMaxEnergy, 
        incomePerMinuteDollars: newIncomePerMinuteDollars,
        operationalCostPerMinuteDollars: newOperationalCostPerMinuteDollars,
        currentPowerGenerated: currentPowerGenerated,
        currentPowerConsumed: currentPowerConsumed,
      ),
      doPersist: true, 
      doNotify: true,
    );
  }
  void recalculateParkStats(){ 
    _recalculateParkStats();
  }

  void skipOneMinute() {
    if (_provider.playerEnergy < SKIP_MINUTE_ENERGY_COST) {
        _logToPark("Not enough energy to fast forward time. Cost: $SKIP_MINUTE_ENERGY_COST⚡", isError: true);
        return;
    }

    final newPlayerEnergy = _provider.playerEnergy - SKIP_MINUTE_ENERGY_COST;
    
    processParkTime(1); // Process one minute of park time, which handles incubation and other per-minute updates
    
    // Note: processParkTime now handles its own recalculation and dollar updates.
    // We just need to set the player energy.
    _provider.setProviderState(
        playerEnergy: newPlayerEnergy,
        doPersist: true, // processParkTime already persists some, this ensures energy is saved too
        doNotify: true
    );
    
    _logToPark("Fast forwarded 1 minute. Energy Cost: $SKIP_MINUTE_ENERGY_COST⚡. Check park log for income/cost details.");
  }

  // New method to process park time based on main task timer
  void processParkTime(int minutes) {
    if (minutes <= 0) return;

    double totalNetIncomeFromTimedActivity = 0;
    List<OwnedDinosaur> currentDinos = List.from(_provider.ownedDinosaurs);

    for (int i = 0; i < minutes; i++) {
        // Update incubating dinosaurs
        currentDinos = currentDinos.map((d) {
            if (d.name.contains("(Incubating)")) {
                OwnedDinosaur updatedDino = OwnedDinosaur.fromJson(d.toJson());
                updatedDino.age +=1; // Each "minute" processed increases age/incubation time by 1 unit
                 final species = _provider.dinosaurSpeciesList.firstWhereOrNull((s) => s.id == updatedDino.speciesId);
                if (species != null && updatedDino.age >= baseIncubationDuration) {
                    updatedDino.name = species.name; // Hatch
                    updatedDino.age = 0; // Reset age for hatched dino
                    _logToPark("${species.name} has hatched during timed activity!");
                }
                return updatedDino;
            }
            return d;
        }).toList();
        
        // Update other statuses (like food, comfort) for hatched dinos
        updateAllDinosaursStatus(); 

        _recalculateParkStats(); 

        int incomeThisMinute = _provider.parkManager.incomePerMinuteDollars;
        int costsThisMinute = _provider.parkManager.operationalCostPerMinuteDollars;
        totalNetIncomeFromTimedActivity += (incomeThisMinute - costsThisMinute);
    }

    final double newParkDollars = _provider.parkManager.parkDollars + totalNetIncomeFromTimedActivity;

    _provider.setProviderState(
        parkManager: _provider.parkManager..parkDollars = newParkDollars.isNegative ? 0 : newParkDollars,
        ownedDinosaurs: currentDinos, // Persist the updated dino list (especially incubation changes)
        doPersist: true,
        doNotify: true
    );

    if (totalNetIncomeFromTimedActivity != 0) {
         _logToPark("Task activity resulted in park income change of \$${totalNetIncomeFromTimedActivity.toStringAsFixed(0)} over $minutes minute(s).");
    }
  }

}