using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace RTM.Configuration
{
    public static class EncryptionHelper
    {
        private static byte[] DeriveKey(string password)
        {
            using (var deriveBytes = new Rfc2898DeriveBytes(password, new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 }))
            {
                return deriveBytes.GetBytes(32); // 256-bit key
            }
        }

        public static string EncryptConfiguration<T>(T config)
        {
            string json = JsonSerializer.Serialize(config);
            string password = Configuration.Password;

            using var aes = Aes.Create();
            aes.Key = DeriveKey(password);
            aes.GenerateIV(); // Generate a new IV for each encryption operation
            var iv = aes.IV;  // Get the generated IV

            var encryptor = aes.CreateEncryptor(aes.Key, aes.IV);

            using var ms = new MemoryStream();
            // Write the IV to the beginning of the stream
            ms.Write(iv, 0, iv.Length);

            using (var cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write))
            using (var sw = new StreamWriter(cs))
            {
                sw.Write(json);
            }

            return Convert.ToBase64String(ms.ToArray());
        }


        public static T DecryptConfiguration<T>(string encryptedData)
        {
            string password = Configuration.Password;
            var buffer = Convert.FromBase64String(encryptedData);

            using var aes = Aes.Create();
            aes.Key = DeriveKey(password);

            // Extract the IV from the beginning of the buffer
            var iv = new byte[aes.BlockSize / 8];
            Array.Copy(buffer, 0, iv, 0, iv.Length);

            aes.IV = iv;
            var decryptor = aes.CreateDecryptor(aes.Key, aes.IV);

            using var ms = new MemoryStream(buffer, iv.Length, buffer.Length - iv.Length);
            using var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read);
            using var sr = new StreamReader(cs);
            var json = sr.ReadToEnd();

            return JsonSerializer.Deserialize<T>(json);
        }
    }

}
