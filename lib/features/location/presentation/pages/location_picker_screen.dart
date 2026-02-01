import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../data/models/location_model.dart';
import '../../../../core/services/location_service.dart';

/// Screen for picking a location from the map
class LocationPickerScreen extends StatefulWidget {
  /// Initial location to show
  final LocationModel? initialLocation;

  /// Title for the app bar
  final String title;

  /// Whether to allow searching for locations
  final bool enableSearch;

  /// Placeholder text for search field
  final String searchHint;

  /// Confirm button text
  final String confirmButtonText;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'Pick Location',
    this.enableSearch = true,
    this.searchHint = 'Search for a place...',
    this.confirmButtonText = 'Confirm Location',
  });

  /// Static method to navigate to this screen and get result
  static Future<LocationModel?> pickLocation(
    BuildContext context, {
    LocationModel? initialLocation,
    String title = 'Pick Location',
    bool enableSearch = true,
  }) async {
    return Navigator.of(context).push<LocationModel>(
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: initialLocation,
          title: title,
          enableSearch: enableSearch,
        ),
      ),
    );
  }

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  
  LocationModel? _selectedLocation;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isFetchingAddress = false;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<LocationModel> _searchResults = [];
  Timer? _debounceTimer;

  LatLng _cameraPosition = const LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _cameraPosition = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
    } else {
      final result = await _locationService.getCurrentLocation();
      if (result.isSuccess && result.data != null) {
        _selectedLocation = result.data;
        _cameraPosition = LatLng(
          result.data!.latitude,
          result.data!.longitude,
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      _cameraPosition = position;
      _isFetchingAddress = true;
    });

    final result = await _locationService.getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (mounted) {
      setState(() {
        _selectedLocation = result.isSuccess && result.data != null
            ? result.data
            : LocationModel(
                latitude: position.latitude,
                longitude: position.longitude,
              );
        _isFetchingAddress = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) return;

      setState(() {
        _isSearching = true;
      });

      final result = await _locationService.getCoordinatesFromAddress(query);

      if (mounted) {
        setState(() {
          if (result.isSuccess && result.data != null) {
            _searchResults = [result.data!];
          } else {
            _searchResults = [];
          }
          _isSearching = false;
        });
      }
    });
  }

  void _onSearchResultSelected(LocationModel location) {
    setState(() {
      _selectedLocation = location;
      _cameraPosition = LatLng(location.latitude, location.longitude);
      _searchResults = [];
      _searchController.clear();
    });

    _searchFocusNode.unfocus();

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        16,
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _locationService.getCurrentLocation();

    if (mounted) {
      if (result.isSuccess && result.data != null) {
        setState(() {
          _selectedLocation = result.data;
          _cameraPosition = LatLng(
            result.data!.latitude,
            result.data!.longitude,
          );
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(result.data!.latitude, result.data!.longitude),
            16,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Could not get location')),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop(_selectedLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          _buildMap(),

          // Center marker
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: Colors.red,
              ),
            ),
          ),

          // Search bar
          if (widget.enableSearch) _buildSearchBar(),

          // Search results
          if (_searchResults.isNotEmpty) _buildSearchResults(),

          // Loading indicator
          if (_isLoading || _isFetchingAddress)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Bottom panel
          _buildBottomPanel(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 140),
        child: FloatingActionButton.small(
          onPressed: _goToCurrentLocation,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _cameraPosition,
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      onTap: _onMapTapped,
      onCameraMove: (position) {
        _cameraPosition = position.target;
      },
      onCameraIdle: () async {
        // Update address when camera stops moving
        if (!_isFetchingAddress) {
          setState(() {
            _isFetchingAddress = true;
          });

          final result = await _locationService.getAddressFromCoordinates(
            _cameraPosition.latitude,
            _cameraPosition.longitude,
          );

          if (mounted) {
            setState(() {
              _selectedLocation = result.isSuccess && result.data != null
                  ? result.data
                  : LocationModel(
                      latitude: _cameraPosition.latitude,
                      longitude: _cameraPosition.longitude,
                    );
              _isFetchingAddress = false;
            });
          }
        }
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Positioned(
      top: 64,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final location = _searchResults[index];
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(location.formattedAddress),
              onTap: () => _onSearchResultSelected(location),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selected location info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Location',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isFetchingAddress
                              ? 'Getting address...'
                              : _selectedLocation?.formattedAddress ??
                                  'Tap on map to select',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Confirm button
              ElevatedButton(
                onPressed:
                    _selectedLocation != null && !_isFetchingAddress
                        ? _confirmLocation
                        : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(widget.confirmButtonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen for viewing a location on the map (read-only)
class LocationViewScreen extends StatelessWidget {
  final LocationModel location;
  final String? title;
  final String? subtitle;

  const LocationViewScreen({
    super.key,
    required this.location,
    this.title,
    this.subtitle,
  });

  /// Static method to navigate to this screen
  static void viewLocation(
    BuildContext context,
    LocationModel location, {
    String? title,
    String? subtitle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationViewScreen(
          location: location,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Location'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(location.latitude, location.longitude),
              zoom: 16,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('location'),
                position: LatLng(location.latitude, location.longitude),
                infoWindow: InfoWindow(
                  title: title ?? 'Location',
                  snippet: subtitle ?? location.formattedAddress,
                ),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.blue.shade400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                      ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            location.formattedAddress,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
