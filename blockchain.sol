// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CertificateRegistry {
    
    // Structure Certificate
    struct Certificate {
        uint256 id;
        string fileName;
        string fileHash;
        address owner;
        address issuer;
        uint256 timestamp;
        bool isValid;
        string metadata;
    }
    
    // Variables d'état
    uint256 private nextCertificateId;
    mapping(uint256 => Certificate) private certificates;
    mapping(address => uint256[]) private ownerCertificates;
    mapping(string => bool) private hashExists;
    
    // Événements
    event FileRegistered(uint256 indexed id, string fileName, address indexed owner, address indexed issuer);
    event CertificateTransferred(uint256 indexed id, address indexed from, address indexed to);
    event CertificateRevoked(uint256 indexed id, address indexed issuer);
    
    // Modificateurs
    modifier onlyIssuer(uint256 _certificateId) {
        require(certificates[_certificateId].issuer == msg.sender, "Only issuer can perform this action");
        _;
    }
    
    modifier onlyOwner(uint256 _certificateId) {
        require(certificates[_certificateId].owner == msg.sender, "Only owner can perform this action");
        _;
    }
    
    modifier certificateExists(uint256 _certificateId) {
        require(_certificateId < nextCertificateId && _certificateId > 0, "Certificate does not exist");
        _;
    }
    
    modifier certificateIsValid(uint256 _certificateId) {
        require(certificates[_certificateId].isValid, "Certificate is not valid");
        _;
    }
    
    /**
     * @dev Enregistre un nouveau fichier/certificat
     */
    function registerFile(
        string memory _fileName,
        string memory _fileHash,
        string memory _metadata
    ) public returns (uint256) {
        require(bytes(_fileName).length > 0, "File name cannot be empty");
        require(bytes(_fileHash).length > 0, "File hash cannot be empty");
        require(!hashExists[_fileHash], "File hash already exists");
        
        uint256 certificateId = nextCertificateId + 1;
        
        Certificate memory newCertificate = Certificate({
            id: certificateId,
            fileName: _fileName,
            fileHash: _fileHash,
            owner: msg.sender,
            issuer: msg.sender,
            timestamp: block.timestamp,
            isValid: true,
            metadata: _metadata
        });
        
        certificates[certificateId] = newCertificate;
        ownerCertificates[msg.sender].push(certificateId);
        hashExists[_fileHash] = true;
        nextCertificateId = certificateId;
        
        emit FileRegistered(certificateId, _fileName, msg.sender, msg.sender);
        
        return certificateId;
    }
    
    /**
     * @dev Transfère la propriété d'un certificat à une nouvelle adresse
     */
    function transfer(uint256 _certificateId, address _newOwner) public 
        certificateExists(_certificateId)
        certificateIsValid(_certificateId)
        onlyOwner(_certificateId)
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != certificates[_certificateId].owner, "New owner must be different");
        
        address oldOwner = certificates[_certificateId].owner;
        
        // Mettre à jour le propriétaire
        certificates[_certificateId].owner = _newOwner;
        
        // Mettre à jour les listes des propriétaires
        _removeFromOwnerList(oldOwner, _certificateId);
        ownerCertificates[_newOwner].push(_certificateId);
        
        emit CertificateTransferred(_certificateId, oldOwner, _newOwner);
    }
    
    /**
     * @dev Récupère les détails d'un certificat
     */
    function getCertificate(uint256 _certificateId) public view 
        certificateExists(_certificateId)
        returns (
            uint256 id,
            string memory fileName,
            string memory fileHash,
            address owner,
            address issuer,
            uint256 timestamp,
            bool isValid,
            string memory metadata
        )
    {
        Certificate storage cert = certificates[_certificateId];
        
        return (
            cert.id,
            cert.fileName,
            cert.fileHash,
            cert.owner,
            cert.issuer,
            cert.timestamp,
            cert.isValid,
            cert.metadata
        );
    }
    
    /**
     * @dev Révoque un certificat (seulement par l'émetteur)
     */
    function revokeCertificate(uint256 _certificateId) public 
        certificateExists(_certificateId)
        onlyIssuer(_certificateId)
    {
        require(certificates[_certificateId].isValid, "Certificate already revoked");
        
        certificates[_certificateId].isValid = false;
        
        emit CertificateRevoked(_certificateId, msg.sender);
    }
    
    /**
     * @dev Récupère tous les certificats d'un propriétaire
     */
    function getCertificatesByOwner(address _owner) public view returns (uint256[] memory) {
        return ownerCertificates[_owner];
    }
    
    /**
     * @dev Vérifie si un hash de fichier existe déjà
     */
    function isHashRegistered(string memory _fileHash) public view returns (bool) {
        return hashExists[_fileHash];
    }
    
    /**
     * @dev Fonction interne pour retirer un certificat de la liste d'un propriétaire
     */
    function _removeFromOwnerList(address _owner, uint256 _certificateId) private {
        uint256[] storage ownerList = ownerCertificates[_owner];
        
        for (uint256 i = 0; i < ownerList.length; i++) {
            if (ownerList[i] == _certificateId) {
                ownerList[i] = ownerList[ownerList.length - 1];
                ownerList.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Récupère le nombre total de certificats enregistrés
     */
    function getTotalCertificates() public view returns (uint256) {
        return nextCertificateId;
    }
}