import Foundation

public enum MumlaModelArtifacts {
    public static let communityPianissimoCoreML = ModelArtifact(
        id: "markstrom/pianissimo-sv-coreml",
        sourceURL: URL(string: "https://huggingface.co/markstrom/pianissimo-sv-coreml")!,
        revision: "106fa163a138a0db6737e0c50494269e07f508d0",
        files: [
            ModelArtifactFile(
                path: "Preprocessor.mlpackage/Data/com.apple.CoreML/model.mlmodel",
                byteCount: 17_913,
                sha256: "44426745838b32d86e0de13054eea2b7c4439e95dadef0bcfa528bdfc93eb630"
            ),
            ModelArtifactFile(
                path: "Preprocessor.mlpackage/Data/com.apple.CoreML/weights/weight.bin",
                byteCount: 1_953_088,
                sha256: "c69139820fc62c199f92c83d2c97458f8aaff337e5026abd9606ff03ba52b8e1"
            ),
            ModelArtifactFile(
                path: "Preprocessor.mlpackage/Manifest.json",
                byteCount: 617,
                sha256: "caffd54a12af3df9bb673f100239919e1047ece8c4035f75819f4adc1d71b6a9"
            ),
            ModelArtifactFile(
                path: "Encoder.mlpackage/Data/com.apple.CoreML/model.mlmodel",
                byteCount: 677_050,
                sha256: "9c9e8a95b18b35142f00ac3c8c186c669057f7ca4a097b2e463c99486eb8eeb8"
            ),
            ModelArtifactFile(
                path: "Encoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin",
                byteCount: 649_181_632,
                sha256: "e9623b969e8f31ba12bfbec7cdcdacb3bfb74e5a3a9bd3a812e4a942c1b1b9ed"
            ),
            ModelArtifactFile(
                path: "Encoder.mlpackage/Manifest.json",
                byteCount: 617,
                sha256: "6d235c39782d2e839142f0df9a6fc3096a6258da05f8be1c1d95547d936cf619"
            ),
            ModelArtifactFile(
                path: "Decoder.mlpackage/Data/com.apple.CoreML/model.mlmodel",
                byteCount: 11_811,
                sha256: "4a36039f091573251bd8bcb55e8f5fa6dc3bad32052d825b1e3b2a3840879990"
            ),
            ModelArtifactFile(
                path: "Decoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin",
                byteCount: 23_604_992,
                sha256: "9e34a5cc5da3477cf0e49126f55d4754a6a332b5df52a22812d6ddbd84af0e39"
            ),
            ModelArtifactFile(
                path: "Decoder.mlpackage/Manifest.json",
                byteCount: 617,
                sha256: "99e8049015d297e58291cfe279c832f01e88959ca91894be939753b19f694827"
            ),
            ModelArtifactFile(
                path: "JointDecisionv3.mlpackage/Data/com.apple.CoreML/model.mlmodel",
                byteCount: 10_827,
                sha256: "af1b876c8677cc8c6676573801038ce6da4972eba4817b1caa2eb09b9ff5ed32"
            ),
            ModelArtifactFile(
                path: "JointDecisionv3.mlpackage/Data/com.apple.CoreML/weights/weight.bin",
                byteCount: 12_642_764,
                sha256: "1f841daf3a6ce483ac136cd7a5e48d6071543e7c5eddcbba4525bda74695cb61"
            ),
            ModelArtifactFile(
                path: "JointDecisionv3.mlpackage/Manifest.json",
                byteCount: 617,
                sha256: "42ab119e793f459e4a8d4a86f77714f093a54ebea55a14786981962985e8121d"
            ),
            ModelArtifactFile(
                path: "parakeet_vocab.json",
                byteCount: 151_122,
                sha256: "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735"
            ),
            ModelArtifactFile(
                path: "LICENSE-and-attribution.txt",
                byteCount: 2_402,
                sha256: "cebcc87c23d9b4df78a1e1655b20c5f82e66babde45362a58fe6a2cb64f3dc91"
            )
        ]
    )
}
